//
//  CMOrder.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class CMAddress;

extern NSString * const CMOrderStatusNew;
extern NSString * const CMOrderStatusAssigned;
extern NSString * const CMOrderStatusPickedUp;
extern NSString * const CMOrderStatusDelivered;
extern NSString * const CMOrderStatusDisputed;
extern NSString * const CMOrderStatusCancelled;

@interface CMOrder : NSManagedObject
@property (nonatomic, copy)             NSString   *orderId;
@property (nonatomic, copy)             NSString   *tenantId;
@property (nonatomic, copy)             NSString   *externalOrderRef;
@property (nonatomic, strong, nullable) CMAddress  *pickupAddress;
@property (nonatomic, strong, nullable) CMAddress  *dropoffAddress;
@property (nonatomic, strong, nullable) NSDate     *pickupWindowStart;
@property (nonatomic, strong, nullable) NSDate     *pickupWindowEnd;
@property (nonatomic, strong, nullable) NSDate     *dropoffWindowStart;
@property (nonatomic, strong, nullable) NSDate     *dropoffWindowEnd;
@property (nonatomic, copy,   nullable) NSString   *pickupTimeZoneIdentifier;
@property (nonatomic, copy,   nullable) NSString   *dropoffTimeZoneIdentifier;
@property (nonatomic, assign)           double      parcelVolumeL;
@property (nonatomic, assign)           double      parcelWeightKg;
@property (nonatomic, copy,   nullable) NSString   *requiresVehicleType;
@property (nonatomic, copy)             NSString   *status;
@property (nonatomic, copy,   nullable) NSString   *assignedCourierId;
@property (nonatomic, copy,   nullable) NSString   *customerNotes;
@property (nonatomic, strong, nullable) NSData     *sensitiveCustomerId;
@property (nonatomic, strong)           NSDate     *createdAt;
@property (nonatomic, strong)           NSDate     *updatedAt;
@property (nonatomic, strong, nullable) NSDate     *deletedAt;
@property (nonatomic, copy,   nullable) NSString   *createdBy;
@property (nonatomic, copy,   nullable) NSString   *updatedBy;
@property (nonatomic, assign)           int64_t     version;

/// YES iff status is delivered, cancelled.
- (BOOL)isTerminal;
@end

NS_ASSUME_NONNULL_END
