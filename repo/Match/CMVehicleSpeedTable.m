//
//  CMVehicleSpeedTable.m
//  CourierMatch
//

#import "CMVehicleSpeedTable.h"
#import "CMItinerary.h"

@implementation CMVehicleSpeedTable

+ (double)speedMphForVehicleType:(NSString *)vehicleType isUrban:(BOOL)isUrban {
    if (!vehicleType) {
        return isUrban ? 25.0 : 45.0;
    }

    if ([vehicleType isEqualToString:CMVehicleTypeBike]) {
        // Bikes: 10 mph regardless of urban/rural
        return 10.0;
    }

    if ([vehicleType isEqualToString:CMVehicleTypeCar] ||
        [vehicleType isEqualToString:CMVehicleTypeVan]) {
        return isUrban ? 25.0 : 45.0;
    }

    if ([vehicleType isEqualToString:CMVehicleTypeTruck]) {
        return isUrban ? 22.0 : 40.0;
    }

    // Unknown vehicle type: default to car speeds.
    return isUrban ? 25.0 : 45.0;
}

+ (double)travelMinutesForMiles:(double)miles
                    vehicleType:(NSString *)vehicleType
                        isUrban:(BOOL)isUrban {
    if (miles <= 0.0) {
        return 0.0;
    }
    double speedMph = [self speedMphForVehicleType:vehicleType isUrban:isUrban];
    if (speedMph <= 0.0) {
        return 0.0;
    }
    // time (hours) = distance / speed => minutes = time * 60
    return (miles / speedMph) * 60.0;
}

@end
