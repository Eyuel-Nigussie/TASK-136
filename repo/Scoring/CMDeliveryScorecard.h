//
//  CMDeliveryScorecard.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMDeliveryScorecard : NSManagedObject
@property (nonatomic, copy)             NSString      *scorecardId;
@property (nonatomic, copy)             NSString      *tenantId;
@property (nonatomic, copy)             NSString      *orderId;
@property (nonatomic, copy)             NSString      *courierId;
@property (nonatomic, copy)             NSString      *rubricId;
@property (nonatomic, assign)           int64_t        rubricVersion;
@property (nonatomic, copy,   nullable) NSString      *supersedesScorecardId;
@property (nonatomic, strong, nullable) NSArray       *automatedResults;
@property (nonatomic, strong, nullable) NSArray       *manualResults;
@property (nonatomic, assign)           double         totalPoints;
@property (nonatomic, assign)           double         maxPoints;
@property (nonatomic, strong, nullable) NSDate        *finalizedAt;
@property (nonatomic, copy,   nullable) NSString      *finalizedBy;
@property (nonatomic, strong)           NSDate        *createdAt;
@property (nonatomic, strong)           NSDate        *updatedAt;
@property (nonatomic, strong, nullable) NSDate        *deletedAt;
@property (nonatomic, copy,   nullable) NSString      *createdBy;
@property (nonatomic, copy,   nullable) NSString      *updatedBy;
@property (nonatomic, assign)           int64_t        version;

- (BOOL)isFinalized;
@end

NS_ASSUME_NONNULL_END
