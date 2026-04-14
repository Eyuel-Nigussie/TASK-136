//
//  CMAuditVerifier.h
//  CourierMatch
//
//  Chain verification for per-tenant audit chains.
//  Walks entries chronologically, recomputes hashes, and compares against stored values.
//  Uses CMWorkAuditCursor for incremental verification (resume from last verified).
//  See design.md §10.3.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/// Progress callback during verification.
/// @param verified   Number of entries verified so far.
/// @param total      Estimated total entries to verify (may be approximate).
typedef void (^CMAuditVerifierProgress)(NSUInteger verified, NSUInteger total);

/// Completion callback for verification.
/// @param success        YES if the chain is intact.
/// @param brokenEntryId  The entryId where the chain broke, or nil if intact.
/// @param error          Describes the failure (CMErrorCodeAuditChainBroken on tampering).
typedef void (^CMAuditVerifierCompletion)(BOOL success,
                                          NSString * _Nullable brokenEntryId,
                                          NSError * _Nullable error);

@interface CMAuditVerifier : NSObject

+ (instancetype)shared;

/// Verifies the hash chain for a tenant. Uses incremental verification:
/// resumes from the last verified entry stored in CMWorkAuditCursor.
/// Runs on a background queue; completion is called on an arbitrary queue.
/// @param tenantId   The tenant to verify.
/// @param progress   Optional progress callback (called periodically).
/// @param completion Called when verification completes.
- (void)verifyChainForTenant:(NSString *)tenantId
                    progress:(nullable CMAuditVerifierProgress)progress
                  completion:(CMAuditVerifierCompletion)completion;

/// Synchronous full-chain verification on the given context.
/// Verifies all entries from the beginning (ignores cursor).
/// @param tenantId   The tenant to verify.
/// @param context    A managed object context to use.
/// @param error      Set on failure.
/// @return YES if the chain is valid.
- (BOOL)verifyFullChainForTenant:(NSString *)tenantId
                         context:(NSManagedObjectContext *)context
                           error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
