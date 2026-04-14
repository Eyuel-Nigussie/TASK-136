//
//  CMVehicleSpeedTable.h
//  CourierMatch
//
//  Average speeds per vehicle type (urban/rural) for offline ETA estimation.
//  See Q3 in questions.md.
//
//  Speeds (mph):
//    bike:          10 (urban and rural)
//    car/van urban: 25
//    car/van rural: 45
//    truck urban:   22
//    truck rural:   40
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMVehicleSpeedTable : NSObject

/// Returns the average speed in mph for the given vehicle type and metro flag.
/// @param vehicleType One of CMVehicleTypeBike, CMVehicleTypeCar, CMVehicleTypeVan, CMVehicleTypeTruck.
/// @param isUrban YES if the route is in a dense metro area (both endpoints metro).
/// @return Speed in mph. Falls back to 25 mph for unknown vehicle types.
+ (double)speedMphForVehicleType:(NSString *)vehicleType isUrban:(BOOL)isUrban;

/// Computes estimated travel time in minutes for a given distance and vehicle type.
/// @param miles Great-circle (or adjusted) distance in miles.
/// @param vehicleType The vehicle type string.
/// @param isUrban YES if both endpoints are in metro areas.
/// @return Travel time in minutes. Returns 0 if miles <= 0 or speed is 0.
+ (double)travelMinutesForMiles:(double)miles
                    vehicleType:(NSString *)vehicleType
                        isUrban:(BOOL)isUrban;

@end

NS_ASSUME_NONNULL_END
