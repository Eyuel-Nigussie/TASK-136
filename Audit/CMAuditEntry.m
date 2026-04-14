#import "CMAuditEntry.h"
@implementation CMAuditEntry
@dynamic entryId, tenantId, actorUserId, actorRole, action;
@dynamic targetType, targetId, beforeJSON, afterJSON, reason;
@dynamic createdAt, prevHash, entryHash;
@end
