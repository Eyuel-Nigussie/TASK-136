//
//  CMMatchCandidate.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMMatchCandidate : NSManagedObject
@property (nonatomic, copy)             NSString   *candidateId;
@property (nonatomic, copy)             NSString   *tenantId;
@property (nonatomic, copy)             NSString   *itineraryId;
@property (nonatomic, copy)             NSString   *orderId;
@property (nonatomic, assign)           double      score;
@property (nonatomic, assign)           double      detourMiles;
@property (nonatomic, assign)           double      timeOverlapMinutes;
@property (nonatomic, assign)           double      capacityRisk;
@property (nonatomic, strong, nullable) NSArray    *explanationComponents;
@property (nonatomic, assign)           int32_t     rankPosition;
@property (nonatomic, strong, nullable) NSDate     *computedAt;
@property (nonatomic, assign)           BOOL        stale;
@property (nonatomic, strong)           NSDate     *createdAt;
@property (nonatomic, strong)           NSDate     *updatedAt;
@property (nonatomic, strong, nullable) NSDate     *deletedAt;
@property (nonatomic, copy,   nullable) NSString   *createdBy;
@property (nonatomic, copy,   nullable) NSString   *updatedBy;
@property (nonatomic, assign)           int64_t     version;
@end

NS_ASSUME_NONNULL_END
