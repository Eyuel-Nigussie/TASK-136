//
//  CMWorkEntities.h
//  CourierMatch
//
//  Lightweight entities stored on the Work (sidecar) store per Q7.
//  These have NSFileProtectionCompleteUntilFirstUserAuthentication so
//  background tasks can access them while the device is locked.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMWorkAttachmentExpiry : NSManagedObject
@property (nonatomic, copy)   NSString *attachmentId;
@property (nonatomic, copy)   NSString *tenantId;
@property (nonatomic, copy)   NSString *storagePath;
@property (nonatomic, strong) NSDate   *expiresAt;
@end

@interface CMWorkNotificationExpiry : NSManagedObject
@property (nonatomic, copy)   NSString *notificationId;
@property (nonatomic, copy)   NSString *tenantId;
@property (nonatomic, strong) NSDate   *expiresAt;
@end

@interface CMWorkAuditCursor : NSManagedObject
@property (nonatomic, copy)             NSString *tenantId;
@property (nonatomic, copy,   nullable) NSString *lastVerifiedEntryId;
@property (nonatomic, strong, nullable) NSDate   *lastVerifiedAt;
@end

NS_ASSUME_NONNULL_END
