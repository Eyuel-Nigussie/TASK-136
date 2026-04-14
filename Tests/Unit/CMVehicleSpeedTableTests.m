//
//  CMVehicleSpeedTableTests.m
//  CourierMatch Tests
//
//  Tests for vehicle speed lookup and travel time computation.
//

#import <XCTest/XCTest.h>
#import "CMVehicleSpeedTable.h"
#import "CMItinerary.h" // for CMVehicleType constants

@interface CMVehicleSpeedTableTests : XCTestCase
@end

@implementation CMVehicleSpeedTableTests

#pragma mark - Bike Urban = 10 mph

- (void)testBikeUrbanSpeed {
    double speed = [CMVehicleSpeedTable speedMphForVehicleType:CMVehicleTypeBike isUrban:YES];
    XCTAssertEqualWithAccuracy(speed, 10.0, 0.001,
        @"Bike urban speed should be 10 mph");
}

#pragma mark - Car Urban = 25 mph, Car Rural = 45 mph

- (void)testCarUrbanSpeed {
    double speed = [CMVehicleSpeedTable speedMphForVehicleType:CMVehicleTypeCar isUrban:YES];
    XCTAssertEqualWithAccuracy(speed, 25.0, 0.001,
        @"Car urban speed should be 25 mph");
}

- (void)testCarRuralSpeed {
    double speed = [CMVehicleSpeedTable speedMphForVehicleType:CMVehicleTypeCar isUrban:NO];
    XCTAssertEqualWithAccuracy(speed, 45.0, 0.001,
        @"Car rural speed should be 45 mph");
}

#pragma mark - Truck Urban = 22 mph, Truck Rural = 40 mph

- (void)testTruckUrbanSpeed {
    double speed = [CMVehicleSpeedTable speedMphForVehicleType:CMVehicleTypeTruck isUrban:YES];
    XCTAssertEqualWithAccuracy(speed, 22.0, 0.001,
        @"Truck urban speed should be 22 mph");
}

- (void)testTruckRuralSpeed {
    double speed = [CMVehicleSpeedTable speedMphForVehicleType:CMVehicleTypeTruck isUrban:NO];
    XCTAssertEqualWithAccuracy(speed, 40.0, 0.001,
        @"Truck rural speed should be 40 mph");
}

#pragma mark - travelMinutesForMiles

- (void)testTravelMinutesForMilesCarUrban {
    // 25 miles at 25 mph should take 60 minutes.
    double minutes = [CMVehicleSpeedTable travelMinutesForMiles:25.0
                                                   vehicleType:CMVehicleTypeCar
                                                       isUrban:YES];
    XCTAssertEqualWithAccuracy(minutes, 60.0, 0.001,
        @"25 miles at car urban (25 mph) should take 60 minutes");
}

@end
