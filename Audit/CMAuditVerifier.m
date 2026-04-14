//
//  CMAuditVerifier.m
//  CourierMatch
//

#import "CMAuditVerifier.h"
#import "CMAuditEntry.h"
#import "CMAuditHashChain.h"
#import "CMAuditRepository.h"
#import "CMCoreDataStack.h"
#import "CMWorkEntities.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSUInteger const kVerifyBatchSize = 200;

@implementation CMAuditVerifier

+ (instancetype)shared {
    static CMAuditVerifier *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMAuditVerifier new]; });
    return s;
}

#pragma mark - Async Incremental Verification

- (void)verifyChainForTenant:(NSString *)tenantId
                    progress:(CMAuditVerifierProgress)progress
                  completion:(CMAuditVerifierCompletion)completion {
    if (!completion) return;

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSError *err = nil;

        // 1. Get the tenant seed.
        NSData *tenantSeed = [CMAuditHashChain ensureSeedForTenant:tenantId error:&err];
        if (!tenantSeed) {
            completion(NO, nil, err);
            return;
        }

        // 2. Look up the incremental cursor from CMWorkAuditCursor.
        NSString *cursorEntryId = nil;
        NSData *cursorPrevHash = nil;
        CMWorkAuditCursor *cursor = [self fetchCursorForTenant:tenantId context:ctx error:&err];
        if (cursor.lastVerifiedEntryId.length > 0) {
            cursorEntryId = cursor.lastVerifiedEntryId;
            // We need the hash of the last verified entry to continue the chain.
            cursorPrevHash = [self hashOfEntryId:cursorEntryId tenantId:tenantId context:ctx error:&err];
        }

        // 3. Walk entries from the cursor forward in batches.
        CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:ctx];
        NSString *afterEntryId = cursorEntryId;
        NSData *expectedPrevHash = cursorPrevHash;
        NSUInteger verified = 0;
        NSString *brokenEntryId = nil;
        BOOL chainValid = YES;

        while (YES) {
            NSError *fetchErr = nil;
            NSArray<CMAuditEntry *> *batch = [repo entriesAfter:afterEntryId
                                                      forTenant:tenantId
                                                          limit:kVerifyBatchSize
                                                          error:&fetchErr];
            if (fetchErr) {
                CMLogError(@"audit.verifier", @"fetch error during verify: %@", fetchErr);
                completion(NO, nil, fetchErr);
                return;
            }
            if (!batch || batch.count == 0) {
                break; // No more entries.
            }

            for (CMAuditEntry *entry in batch) {
                // Verify prevHash linkage.
                if (![self data:entry.prevHash isEqualToData:expectedPrevHash]) {
                    brokenEntryId = entry.entryId;
                    chainValid = NO;
                    break;
                }

                // Recompute the hash and compare.
                NSData *computed = [CMAuditHashChain computeHashForEntry:entry
                                                               prevHash:entry.prevHash
                                                             tenantSeed:tenantSeed];
                if (![computed isEqualToData:entry.entryHash]) {
                    brokenEntryId = entry.entryId;
                    chainValid = NO;
                    break;
                }

                expectedPrevHash = entry.entryHash;
                afterEntryId = entry.entryId;
                verified++;

                if (progress && verified % 50 == 0) {
                    progress(verified, verified); // total is approximate
                }
            }

            if (!chainValid) break;
        }

        // 4. Update the cursor if verification passed.
        if (chainValid && afterEntryId.length > 0) {
            [self updateCursor:cursor
                      tenantId:tenantId
             lastVerifiedEntry:afterEntryId
                       context:ctx];
            NSError *saveErr = nil;
            [ctx cm_saveWithError:&saveErr];
            if (saveErr) {
                CMLogWarn(@"audit.verifier", @"cursor save failed: %@", saveErr);
            }
        }

        if (progress) {
            progress(verified, verified);
        }

        if (chainValid) {
            CMLogInfo(@"audit.verifier", @"chain valid for tenant %@, %lu entries verified",
                      tenantId, (unsigned long)verified);
            completion(YES, nil, nil);
        } else {
            NSError *chainErr = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                               message:[NSString stringWithFormat:
                                                        @"Chain broken at entry %@", brokenEntryId]];
            CMLogError(@"audit.verifier", @"chain BROKEN for tenant %@ at entry %@",
                       tenantId, brokenEntryId);
            completion(NO, brokenEntryId, chainErr);
        }
    }];
}

#pragma mark - Sync Full Verification

- (BOOL)verifyFullChainForTenant:(NSString *)tenantId
                         context:(NSManagedObjectContext *)context
                           error:(NSError **)error {
    // Get the tenant seed.
    NSData *tenantSeed = [CMAuditHashChain ensureSeedForTenant:tenantId error:error];
    if (!tenantSeed) {
        return NO;
    }

    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:context];
    NSString *afterEntryId = nil;
    NSData *expectedPrevHash = nil;

    while (YES) {
        NSError *fetchErr = nil;
        NSArray<CMAuditEntry *> *batch = [repo entriesAfter:afterEntryId
                                                  forTenant:tenantId
                                                      limit:kVerifyBatchSize
                                                      error:&fetchErr];
        if (fetchErr) {
            if (error) *error = fetchErr;
            return NO;
        }
        if (!batch || batch.count == 0) {
            break;
        }

        for (CMAuditEntry *entry in batch) {
            // Verify prevHash linkage.
            if (![self data:entry.prevHash isEqualToData:expectedPrevHash]) {
                if (error) {
                    *error = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                            message:[NSString stringWithFormat:
                                                     @"Chain broken at entry %@: prevHash mismatch",
                                                     entry.entryId]
                                           userInfo:@{@"brokenEntryId": entry.entryId ?: @""}];
                }
                return NO;
            }

            // Recompute hash.
            NSData *computed = [CMAuditHashChain computeHashForEntry:entry
                                                            prevHash:entry.prevHash
                                                          tenantSeed:tenantSeed];
            if (![computed isEqualToData:entry.entryHash]) {
                if (error) {
                    *error = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                            message:[NSString stringWithFormat:
                                                     @"Chain broken at entry %@: entryHash mismatch",
                                                     entry.entryId]
                                           userInfo:@{@"brokenEntryId": entry.entryId ?: @""}];
                }
                return NO;
            }

            expectedPrevHash = entry.entryHash;
            afterEntryId = entry.entryId;
        }
    }

    return YES;
}

#pragma mark - Cursor Management

- (CMWorkAuditCursor *)fetchCursorForTenant:(NSString *)tenantId
                                    context:(NSManagedObjectContext *)context
                                      error:(NSError **)error {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"WorkAuditCursor"];
    req.predicate = [NSPredicate predicateWithFormat:@"tenantId == %@", tenantId];
    req.fetchLimit = 1;
    NSArray *results = [context cm_executeFetch:req error:error];
    return results.firstObject;
}

- (void)updateCursor:(CMWorkAuditCursor *)cursor
            tenantId:(NSString *)tenantId
   lastVerifiedEntry:(NSString *)lastEntryId
             context:(NSManagedObjectContext *)context {
    if (!cursor) {
        // Create a new cursor.
        cursor = [NSEntityDescription insertNewObjectForEntityForName:@"WorkAuditCursor"
                                              inManagedObjectContext:context];
        cursor.tenantId = tenantId;
    }
    cursor.lastVerifiedEntryId = lastEntryId;
    cursor.lastVerifiedAt = [NSDate date];
}

- (NSData *)hashOfEntryId:(NSString *)entryId
                 tenantId:(NSString *)tenantId
                  context:(NSManagedObjectContext *)context
                    error:(NSError **)error {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
    req.predicate = [NSPredicate predicateWithFormat:@"entryId == %@ AND tenantId == %@",
                     entryId, tenantId];
    req.fetchLimit = 1;
    NSArray *results = [context cm_executeFetch:req error:error];
    CMAuditEntry *entry = results.firstObject;
    return entry.entryHash;
}

#pragma mark - Helpers

- (BOOL)data:(NSData *)a isEqualToData:(NSData *)b {
    if (a == nil && b == nil) return YES;
    if (a == nil || b == nil) return NO;
    return [a isEqualToData:b];
}

@end
