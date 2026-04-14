//
//  CMGeoMathTests.m
//  CourierMatch Tests
//
//  Tests for geographic math utilities: Haversine distance, multi-leg,
//  and bounding-box membership.
//

#import <XCTest/XCTest.h>
#import "CMGeoMath.h"

@interface CMGeoMathTests : XCTestCase
@end

@implementation CMGeoMathTests

#pragma mark - Distance: Same Point

- (void)testDistanceSamePointIsZero {
    double d = CMGeoDistanceMiles(40.7128, -74.0060, 40.7128, -74.0060);
    XCTAssertEqualWithAccuracy(d, 0.0, 0.001,
        @"Distance from a point to itself must be zero");
}

#pragma mark - Distance: Known NYC to LA

- (void)testDistanceNYCtoLA {
    // NYC: 40.7128, -74.0060  LA: 34.0522, -118.2437
    double d = CMGeoDistanceMiles(40.7128, -74.0060, 34.0522, -118.2437);
    XCTAssertEqualWithAccuracy(d, 2451.0, 50.0,
        @"NYC to LA should be approximately 2451 miles (±50)");
}

#pragma mark - Multi-Leg Distance >= Direct Distance

- (void)testMultiLegDistanceGreaterThanOrEqualToDirect {
    // origin = NYC, destination = LA
    double originLat = 40.7128, originLng = -74.0060;
    double destLat   = 34.0522, destLng   = -118.2437;

    // intermediate points: Chicago (41.8781, -87.6298) and Denver (39.7392, -104.9903)
    double pickupLat  = 41.8781, pickupLng  = -87.6298;
    double dropoffLat = 39.7392, dropoffLng = -104.9903;

    double direct   = CMGeoDistanceMiles(originLat, originLng, destLat, destLng);
    double multiLeg = CMGeoMultiLegDistanceMiles(originLat, originLng,
                                                  pickupLat, pickupLng,
                                                  dropoffLat, dropoffLng,
                                                  destLat, destLng);
    XCTAssertGreaterThanOrEqual(multiLeg, direct,
        @"Multi-leg distance must be >= direct distance due to triangle inequality");
}

#pragma mark - Bounding Box: Center Point Contained

- (void)testBoundingBoxContainsCenterPoint {
    double centerLat = 40.7128, centerLng = -74.0060;
    double radiusMiles = 10.0;

    BOOL inside = CMGeoPointInBoundingBox(centerLat, centerLng,
                                          centerLat, centerLng, radiusMiles);
    XCTAssertTrue(inside,
        @"The center point must always be inside its own bounding box");
}

#pragma mark - Bounding Box: Point Outside Returns NO

- (void)testBoundingBoxPointOutsideReturnsNO {
    double centerLat = 40.7128, centerLng = -74.0060;
    double radiusMiles = 1.0;  // Very small radius: ~1/69 degree latitude

    // A point 100 miles north should be well outside a 1-mile box.
    double farLat = centerLat + 2.0;  // ~138 miles north
    double farLng = centerLng;

    BOOL inside = CMGeoPointInBoundingBox(farLat, farLng,
                                          centerLat, centerLng, radiusMiles);
    XCTAssertFalse(inside,
        @"A point far outside the bounding box must return NO");
}

#pragma mark - Bounding Box: Point at Edge

- (void)testBoundingBoxPointAtEdge {
    double centerLat = 40.0, centerLng = -74.0;
    double radiusMiles = 69.0; // 69 miles ~ 1 degree of latitude

    // Compute the exact bounding box boundaries.
    double minLat, maxLat, minLng, maxLng;
    CMGeoBoundingBox(centerLat, centerLng, radiusMiles,
                     &minLat, &maxLat, &minLng, &maxLng);

    // A point at the max latitude edge should be inside (using <= comparison).
    BOOL atMaxLatEdge = CMGeoPointInBoundingBox(maxLat, centerLng,
                                                 centerLat, centerLng, radiusMiles);
    XCTAssertTrue(atMaxLatEdge,
        @"Point at the maxLat boundary edge should be included (<=)");

    // A point at the min latitude edge should be inside.
    BOOL atMinLatEdge = CMGeoPointInBoundingBox(minLat, centerLng,
                                                 centerLat, centerLng, radiusMiles);
    XCTAssertTrue(atMinLatEdge,
        @"Point at the minLat boundary edge should be included (>=)");

    // A point just beyond the max latitude edge should be outside.
    BOOL justBeyondMaxLat = CMGeoPointInBoundingBox(maxLat + 0.001, centerLng,
                                                     centerLat, centerLng, radiusMiles);
    XCTAssertFalse(justBeyondMaxLat,
        @"Point just beyond maxLat boundary should NOT be included");
}

@end
