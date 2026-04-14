#import "CMWorkEntities.h"

@implementation CMWorkAttachmentExpiry
@dynamic attachmentId, tenantId, storagePath, expiresAt;
@end

@implementation CMWorkNotificationExpiry
@dynamic notificationId, tenantId, expiresAt;
@end

@implementation CMWorkAuditCursor
@dynamic tenantId, lastVerifiedEntryId, lastVerifiedAt;
@end
