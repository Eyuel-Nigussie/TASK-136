//
//  CMItinerary.m
//  CourierMatch
//

#import "CMItinerary.h"

NSString * const CMItineraryStatusDraft     = @"draft";
NSString * const CMItineraryStatusActive    = @"active";
NSString * const CMItineraryStatusCompleted = @"completed";
NSString * const CMItineraryStatusCancelled = @"cancelled";

NSString * const CMVehicleTypeBike  = @"bike";
NSString * const CMVehicleTypeCar   = @"car";
NSString * const CMVehicleTypeVan   = @"van";
NSString * const CMVehicleTypeTruck = @"truck";

@implementation CMItinerary
@dynamic itineraryId, tenantId, courierId;
@dynamic originAddress, destinationAddress;
@dynamic departureWindowStart, departureWindowEnd;
@dynamic vehicleType, vehicleCapacityVolumeL, vehicleCapacityWeightKg;
@dynamic onTheWayStops, status;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
