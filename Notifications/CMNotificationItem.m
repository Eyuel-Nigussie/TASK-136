#import "CMNotificationItem.h"
NSString * const CMNotificationStatusActive    = @"active";
NSString * const CMNotificationStatusCoalesced = @"coalesced";
@implementation CMNotificationItem
@dynamic notificationId, tenantId, subjectEntityType, subjectEntityId;
@dynamic templateKey, payloadJSON, renderedTitle, renderedBody;
@dynamic recipientUserId, status, childIds, rateLimitBucket;
@dynamic createdAt, readAt, ackedAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
