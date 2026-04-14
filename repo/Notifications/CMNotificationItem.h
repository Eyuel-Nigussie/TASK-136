//
//  CMNotificationItem.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMNotificationStatusActive;
extern NSString * const CMNotificationStatusCoalesced;

@interface CMNotificationItem : NSManagedObject
@property (nonatomic, copy)             NSString      *notificationId;
@property (nonatomic, copy)             NSString      *tenantId;
@property (nonatomic, copy,   nullable) NSString      *subjectEntityType;
@property (nonatomic, copy,   nullable) NSString      *subjectEntityId;
@property (nonatomic, copy)             NSString      *templateKey;
@property (nonatomic, strong, nullable) NSDictionary  *payloadJSON;
@property (nonatomic, copy,   nullable) NSString      *renderedTitle;
@property (nonatomic, copy,   nullable) NSString      *renderedBody;
@property (nonatomic, copy)             NSString      *recipientUserId;
@property (nonatomic, copy)             NSString      *status;
@property (nonatomic, strong, nullable) NSArray       *childIds;
@property (nonatomic, copy,   nullable) NSString      *rateLimitBucket;
@property (nonatomic, strong)           NSDate        *createdAt;
@property (nonatomic, strong, nullable) NSDate        *readAt;
@property (nonatomic, strong, nullable) NSDate        *ackedAt;
@property (nonatomic, strong)           NSDate        *updatedAt;
@property (nonatomic, strong, nullable) NSDate        *deletedAt;
@property (nonatomic, copy,   nullable) NSString      *createdBy;
@property (nonatomic, copy,   nullable) NSString      *updatedBy;
@property (nonatomic, assign)           int64_t        version;
@end

NS_ASSUME_NONNULL_END
