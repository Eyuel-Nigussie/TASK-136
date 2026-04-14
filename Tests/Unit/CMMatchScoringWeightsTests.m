//
//  CMMatchScoringWeightsTests.m
//  CourierMatch Tests
//
//  Tests for scoring weights configuration: defaults, tenant overrides,
//  missing keys, and computed properties.
//

#import <XCTest/XCTest.h>
#import "CMMatchScoringWeights.h"

@interface CMMatchScoringWeightsTests : XCTestCase
@end

@implementation CMMatchScoringWeightsTests

#pragma mark - Default Weights Match Design

- (void)testDefaultWeightsMatchDesign {
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] init];
    XCTAssertEqualWithAccuracy(w.wTime, 30.0, 0.001, @"wTime default should be 30");
    XCTAssertEqualWithAccuracy(w.wDetour, 20.0, 0.001, @"wDetour default should be 20");
    XCTAssertEqualWithAccuracy(w.wCapacity, 15.0, 0.001, @"wCapacity default should be 15");
    XCTAssertEqualWithAccuracy(w.wVehicle, 10.0, 0.001, @"wVehicle default should be 10");
}

#pragma mark - Default Thresholds

- (void)testDefaultThresholds {
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] init];
    XCTAssertEqualWithAccuracy(w.maxDetourMiles, 8.0, 0.001,
        @"maxDetourMiles default should be 8.0");
    XCTAssertEqualWithAccuracy(w.minTimeOverlapMinutes, 20.0, 0.001,
        @"minTimeOverlapMinutes default should be 20");
}

#pragma mark - initWithTenantConfig Overrides Specific Keys

- (void)testInitWithTenantConfigOverridesSpecificKeys {
    NSDictionary *config = @{
        @"w_time": @(50.0),
        @"maxDetourMiles": @(12.0),
    };
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] initWithTenantConfig:config];

    XCTAssertEqualWithAccuracy(w.wTime, 50.0, 0.001,
        @"wTime should be overridden to 50");
    XCTAssertEqualWithAccuracy(w.maxDetourMiles, 12.0, 0.001,
        @"maxDetourMiles should be overridden to 12");
    // Non-overridden values should retain defaults.
    XCTAssertEqualWithAccuracy(w.wDetour, 20.0, 0.001,
        @"wDetour should remain at default 20");
    XCTAssertEqualWithAccuracy(w.wCapacity, 15.0, 0.001,
        @"wCapacity should remain at default 15");
}

#pragma mark - Missing Keys in Config Keep Defaults

- (void)testMissingKeysInConfigKeepDefaults {
    NSDictionary *config = @{@"somethingUnrelated": @(99.0)};
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] initWithTenantConfig:config];

    XCTAssertEqualWithAccuracy(w.wTime, 30.0, 0.001);
    XCTAssertEqualWithAccuracy(w.wDetour, 20.0, 0.001);
    XCTAssertEqualWithAccuracy(w.wCapacity, 15.0, 0.001);
    XCTAssertEqualWithAccuracy(w.wVehicle, 10.0, 0.001);
    XCTAssertEqualWithAccuracy(w.maxDetourMiles, 8.0, 0.001);
    XCTAssertEqualWithAccuracy(w.minTimeOverlapMinutes, 20.0, 0.001);
}

#pragma mark - maxPossibleScore = Sum of All Weights

- (void)testMaxPossibleScoreIsSumOfAllWeights {
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] init];
    double expected = 30.0 + 20.0 + 15.0 + 10.0; // = 75.0
    XCTAssertEqualWithAccuracy([w maxPossibleScore], expected, 0.001,
        @"maxPossibleScore should be the sum of all weights (75)");
}

#pragma mark - maxCandidatesPerItinerary Default

- (void)testMaxCandidatesPerItineraryDefault {
    CMMatchScoringWeights *w = [[CMMatchScoringWeights alloc] init];
    XCTAssertEqual(w.maxCandidatesPerItinerary, (NSUInteger)500,
        @"maxCandidatesPerItinerary default should be 500");
}

@end
