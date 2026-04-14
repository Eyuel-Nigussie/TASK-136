#import "CMAuditEntry.h"
#import "CMDebugLogger.h"

@implementation CMAuditEntry
@dynamic entryId, tenantId, actorUserId, actorRole, action;
@dynamic targetType, targetId, beforeJSON, afterJSON, reason;
@dynamic createdAt, prevHash, entryHash;

/// Enforce write-once semantics: reject modifications to persisted audit entries.
/// New inserts (temporaryID) are allowed; updates to committed objects are rolled back.
- (void)willSave {
    [super willSave];

    // Allow new inserts (object has a temporary ID and has never been committed).
    if (self.objectID.isTemporaryID) {
        return;
    }

    // If this is a persisted object that has been modified (not deleted), reject the mutation.
    if (self.hasChanges && !self.isDeleted && self.changedValues.count > 0) {
        CMLogError(@"audit.immutability", @"Blocked mutation of persisted AuditEntry %@", self.entryId);
        [self.managedObjectContext refreshObject:self mergeChanges:NO];
    }

    // Block deletions of persisted entries.
    if (self.isDeleted) {
        CMLogError(@"audit.immutability", @"Blocked deletion of AuditEntry %@", self.entryId);
        [self.managedObjectContext refreshObject:self mergeChanges:NO];
    }
}

@end
