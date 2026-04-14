#import "CMAttachment.h"
NSString * const CMAttachmentHashStatusPending  = @"pending";
NSString * const CMAttachmentHashStatusReady    = @"ready";
NSString * const CMAttachmentHashStatusTampered = @"tampered";
@implementation CMAttachment
@dynamic attachmentId, tenantId, ownerType, ownerId, filename, mimeType;
@dynamic sizeBytes, sha256Hex, capturedAt, expiresAt, storagePathRelative;
@dynamic capturedByUserId, hashStatus;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
