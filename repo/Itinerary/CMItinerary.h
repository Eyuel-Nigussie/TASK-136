//
//  CMItinerary.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class CMAddress;

extern NSString * const CMItineraryStatusDraft;
extern NSString * const CMItineraryStatusActive;
extern NSString * const CMItineraryStatusCompleted;
extern NSString * const CMItineraryStatusCancelled;

extern NSString * const CMVehicleTypeBike;
extern NSString * const CMVehicleTypeCar;
extern NSString * const CMVehicleTypeVan;
extern NSString * const CMVehicleTypeTruck;

@interface CMItinerary : NSManagedObject
@property (nonatomic, copy)             NSString   *itineraryId;
@property (nonatomic, copy)             NSString   *tenantId;
@property (nonatomic, copy)             NSString   *courierId;
@property (nonatomic, strong, nullable) CMAddress  *originAddress;
@property (nonatomic, strong, nullable) CMAddress  *destinationAddress;
@property (nonatomic, strong, nullable) NSDate     *departureWindowStart;
@property (nonatomic, strong, nullable) NSDate     *departureWindowEnd;
@property (nonatomic, copy)             NSString   *vehicleType;
@property (nonatomic, assign)           double      vehicleCapacityVolumeL;
@property (nonatomic, assign)           double      vehicleCapacityWeightKg;
@property (nonatomic, strong, nullable) NSArray<CMAddress *> *onTheWayStops;
@property (nonatomic, copy)             NSString   *status;
@property (nonatomic, strong)           NSDate     *createdAt;
@property (nonatomic, strong)           NSDate     *updatedAt;
@property (nonatomic, strong, nullable) NSDate     *deletedAt;
@property (nonatomic, copy,   nullable) NSString   *createdBy;
@property (nonatomic, copy,   nullable) NSString   *updatedBy;
@property (nonatomic, assign)           int64_t     version;
@end

NS_ASSUME_NONNULL_END
