//
//  CMDispute.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMDisputeStatusOpen;
extern NSString * const CMDisputeStatusInReview;
extern NSString * const CMDisputeStatusResolved;
extern NSString * const CMDisputeStatusRejected;

@interface CMDispute : NSManagedObject
@property (nonatomic, copy)             NSString *disputeId;
@property (nonatomic, copy)             NSString *tenantId;
@property (nonatomic, copy)             NSString *orderId;
@property (nonatomic, copy)             NSString *openedBy;
@property (nonatomic, strong)           NSDate   *openedAt;
@property (nonatomic, copy)             NSString *reason;
@property (nonatomic, copy,   nullable) NSString *reasonCategory;
@property (nonatomic, copy)             NSString *status;
@property (nonatomic, copy,   nullable) NSString *reviewerId;
@property (nonatomic, copy,   nullable) NSString *resolution;
@property (nonatomic, strong, nullable) NSDate   *closedAt;
@property (nonatomic, strong)           NSDate   *createdAt;
@property (nonatomic, strong)           NSDate   *updatedAt;
@property (nonatomic, strong, nullable) NSDate   *deletedAt;
@property (nonatomic, copy,   nullable) NSString *createdBy;
@property (nonatomic, copy,   nullable) NSString *updatedBy;
@property (nonatomic, assign)           int64_t   version;
@end

NS_ASSUME_NONNULL_END
