//
//  CMAuditService.m
//  CourierMatch
//

#import "CMAuditService.h"
#import "CMAuditEntry.h"
#import "CMAuditHashChain.h"
#import "CMAuditMetaChain.h"
#import "CMAuditRepository.h"
#import "CMTenantContext.h"
#import "CMCoreDataStack.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMAuditService

+ (instancetype)shared {
    static CMAuditService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMAuditService new]; });
    return s;
}

#pragma mark - Async Public API

- (void)recordAction:(NSString *)action
          targetType:(NSString *)targetType
            targetId:(NSString *)targetId
          beforeJSON:(NSDictionary *)beforeJSON
           afterJSON:(NSDictionary *)afterJSON
              reason:(NSString *)reason
          completion:(CMAuditServiceCompletion)completion {

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSError *err = nil;
        CMAuditEntry *entry = [self recordActionSync:action
                                          targetType:targetType
                                            targetId:targetId
                                          beforeJSON:beforeJSON
                                           afterJSON:afterJSON
                                              reason:reason
                                             context:ctx
                                               error:&err];
        if (entry) {
            // Save the context.
            NSError *saveErr = nil;
            if (![ctx cm_saveWithError:&saveErr]) {
                CMLogError(@"audit.service", @"save failed for action '%@': %@", action, saveErr);
                if (completion) {
                    completion(nil, saveErr);
                }
                return;
            }
        }
        if (completion) {
            completion(entry, err);
        }
    }];
}

- (void)recordPermissionChangeForSubject:(NSString *)subjectUserId
                                 oldRole:(NSString *)oldRole
                                 newRole:(NSString *)newRole
                                  reason:(NSString *)reason
                              completion:(CMAuditServiceCompletion)completion {

    NSDictionary *beforeJSON = @{@"role": oldRole ?: @""};
    NSDictionary *afterJSON  = @{@"role": newRole ?: @""};

    [self recordAction:@"permission.role_changed"
            targetType:@"User"
              targetId:subjectUserId
            beforeJSON:beforeJSON
             afterJSON:afterJSON
                reason:reason
            completion:completion];
}

#pragma mark - Sync Public API

- (CMAuditEntry *)recordActionSync:(NSString *)action
                         targetType:(NSString *)targetType
                           targetId:(NSString *)targetId
                         beforeJSON:(NSDictionary *)beforeJSON
                          afterJSON:(NSDictionary *)afterJSON
                             reason:(NSString *)reason
                            context:(NSManagedObjectContext *)context
                              error:(NSError **)error {

    CMTenantContext *tc = [CMTenantContext shared];
    NSString *tenantId   = tc.currentTenantId;
    NSString *actorId    = tc.currentUserId;
    NSString *actorRole  = tc.currentRole;

    if (!tenantId.length || !actorId.length) {
        NSError *e = [CMError errorWithCode:CMErrorCodeAuditWriteFailed
                                    message:@"Cannot write audit entry: no tenant context"];
        CMLogError(@"audit.service", @"%@", e.localizedDescription);
        if (error) *error = e;
        return nil;
    }

    // 1. Ensure per-tenant seed exists.
    NSError *seedErr = nil;
    NSData *tenantSeed = [CMAuditHashChain ensureSeedForTenant:tenantId error:&seedErr];
    if (!tenantSeed) {
        CMLogError(@"audit.service", @"seed missing for tenant %@: %@", tenantId, seedErr);
        if (error) *error = seedErr;
        return nil;
    }

    // 2. Fetch the latest chain head for this tenant to get prevHash.
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:context];
    NSError *fetchErr = nil;
    CMAuditEntry *latestEntry = [repo latestEntryForTenant:tenantId error:&fetchErr];
    if (fetchErr) {
        CMLogWarn(@"audit.service", @"failed to fetch latest entry: %@", fetchErr);
        // Non-fatal: this may be the first entry.
    }
    NSData *prevHash = latestEntry.entryHash;

    // 3. Create the new entry via the repository (stamps entryId + createdAt).
    CMAuditEntry *entry = [repo insertEntry];
    entry.tenantId     = tenantId;
    entry.actorUserId  = actorId;
    entry.actorRole    = actorRole ?: @"";
    entry.action       = action;
    entry.targetType   = targetType;
    entry.targetId     = targetId;
    entry.beforeJSON   = beforeJSON;
    entry.afterJSON    = afterJSON;
    entry.reason       = reason;
    entry.prevHash     = prevHash;

    // 4. Compute the entry hash: HMAC-SHA256(tenantSeed, prevHash || canonicalJSON).
    NSData *entryHash = [CMAuditHashChain computeHashForEntry:entry
                                                     prevHash:prevHash
                                                   tenantSeed:tenantSeed];
    entry.entryHash = entryHash;

    // 5. Update the device-wide meta-chain.
    NSError *metaErr = nil;
    if (![[CMAuditMetaChain shared] recordHeadChangeForTenant:tenantId
                                                      newHead:entryHash
                                                  actorUserId:actorId
                                                        error:&metaErr]) {
        CMLogWarn(@"audit.service", @"meta-chain update failed: %@", metaErr);
        // Meta-chain failure is logged but does not block the audit entry write.
        // The tenant chain itself remains intact.
    }

    CMLogInfo(@"audit.service", @"recorded '%@' entry=%@ tenant=%@",
              action, entry.entryId, tenantId);

    return entry;
}

@end
