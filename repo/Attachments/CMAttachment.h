//
//  CMAttachment.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMAttachmentHashStatusPending;
extern NSString * const CMAttachmentHashStatusReady;
extern NSString * const CMAttachmentHashStatusTampered;

@interface CMAttachment : NSManagedObject
@property (nonatomic, copy)             NSString *attachmentId;
@property (nonatomic, copy)             NSString *tenantId;
@property (nonatomic, copy)             NSString *ownerType;
@property (nonatomic, copy)             NSString *ownerId;
@property (nonatomic, copy)             NSString *filename;
@property (nonatomic, copy)             NSString *mimeType;
@property (nonatomic, assign)           int64_t   sizeBytes;
@property (nonatomic, copy,   nullable) NSString *sha256Hex;
@property (nonatomic, strong)           NSDate   *capturedAt;
@property (nonatomic, strong)           NSDate   *expiresAt;
@property (nonatomic, copy)             NSString *storagePathRelative;
@property (nonatomic, copy)             NSString *capturedByUserId;
@property (nonatomic, copy)             NSString *hashStatus;
@property (nonatomic, strong)           NSDate   *createdAt;
@property (nonatomic, strong)           NSDate   *updatedAt;
@property (nonatomic, strong, nullable) NSDate   *deletedAt;
@property (nonatomic, copy,   nullable) NSString *createdBy;
@property (nonatomic, copy,   nullable) NSString *updatedBy;
@property (nonatomic, assign)           int64_t   version;
@end

NS_ASSUME_NONNULL_END
