#import "CMAuditEntry.h"

@implementation CMAuditEntry
@dynamic entryId, tenantId, actorUserId, actorRole, action;
@dynamic targetType, targetId, beforeJSON, afterJSON, reason;
@dynamic createdAt, prevHash, entryHash;

// Write-once semantics are enforced at the CMAuditRepository layer:
// - insertEntry is the only write path exposed by the repository
// - No update/delete methods are offered
// - The hash-chain verifier provides secondary tamper detection
//
// willSave is intentionally NOT overridden here. Core Data's managed-object
// lifecycle must remain unblocked so that the chain verifier's tamper-detection
// tests can deliberately mutate entries to prove the verifier catches it.

@end
