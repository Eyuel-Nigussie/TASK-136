//
//  CMMatchExplanationTests.m
//  CourierMatch Tests
//
//  Tests for explanation component arrays and summary string rendering.
//

#import <XCTest/XCTest.h>
#import "CMMatchExplanation.h"

@interface CMMatchExplanationTests : XCTestCase
@end

@implementation CMMatchExplanationTests

#pragma mark - Components Array Has 4 Entries in Order

- (void)testComponentsArrayHas4EntriesInOrder {
    NSArray *components = [CMMatchExplanation componentsWithTimeDelta:30.0
                                                          detourDelta:20.0
                                                        capacityDelta:15.0
                                                         vehicleDelta:10.0];

    XCTAssertEqual(components.count, 4u, @"Should have exactly 4 components");

    XCTAssertEqualObjects(components[0][@"label"], @"time fit",
        @"First component must be time fit");
    XCTAssertEqualObjects(components[1][@"label"], @"detour",
        @"Second component must be detour");
    XCTAssertEqualObjects(components[2][@"label"], @"capacity",
        @"Third component must be capacity");
    XCTAssertEqualObjects(components[3][@"label"], @"vehicle",
        @"Fourth component must be vehicle");
}

#pragma mark - summaryString Format

- (void)testSummaryStringFormat {
    NSArray *components = [CMMatchExplanation componentsWithTimeDelta:30.0
                                                          detourDelta:20.0
                                                        capacityDelta:15.0
                                                         vehicleDelta:10.0];
    NSString *summary = [CMMatchExplanation summaryStringFromComponents:components];

    XCTAssertEqualObjects(summary,
        @"+30.0 time fit, +20.0 detour, +15.0 capacity, +10.0 vehicle",
        @"Summary string must match the expected format with + prefix for positive values");
}

#pragma mark - Negative Deltas Render with Minus Sign

- (void)testNegativeDeltasRenderWithMinusSign {
    NSArray *components = [CMMatchExplanation componentsWithTimeDelta:-5.0
                                                          detourDelta:-3.0
                                                        capacityDelta:-2.0
                                                         vehicleDelta:-1.0];
    NSString *summary = [CMMatchExplanation summaryStringFromComponents:components];

    // Negative values should appear with a minus sign, no + prefix.
    XCTAssertTrue([summary containsString:@"-5.0 time fit"],
        @"Negative time delta should render with minus sign, got: %@", summary);
    XCTAssertTrue([summary containsString:@"-3.0 detour"],
        @"Negative detour delta should render with minus sign, got: %@", summary);
    XCTAssertTrue([summary containsString:@"-2.0 capacity"],
        @"Negative capacity delta should render with minus sign, got: %@", summary);
    XCTAssertTrue([summary containsString:@"-1.0 vehicle"],
        @"Negative vehicle delta should render with minus sign, got: %@", summary);
}

#pragma mark - Zero Deltas Still Included

- (void)testZeroDeltasStillIncluded {
    NSArray *components = [CMMatchExplanation componentsWithTimeDelta:0.0
                                                          detourDelta:0.0
                                                        capacityDelta:0.0
                                                         vehicleDelta:0.0];
    NSString *summary = [CMMatchExplanation summaryStringFromComponents:components];

    XCTAssertEqual(components.count, 4u,
        @"All 4 components should be present even if zero");
    XCTAssertTrue([summary containsString:@"+0.0 time fit"],
        @"Zero time delta should still be included, got: %@", summary);
    XCTAssertTrue([summary containsString:@"+0.0 detour"],
        @"Zero detour delta should still be included, got: %@", summary);
    XCTAssertTrue([summary containsString:@"+0.0 capacity"],
        @"Zero capacity delta should still be included, got: %@", summary);
    XCTAssertTrue([summary containsString:@"+0.0 vehicle"],
        @"Zero vehicle delta should still be included, got: %@", summary);
}

#pragma mark - timeFitExplanationWithETA

- (void)testTimeFitExplanation_WithValidDates {
    NSDate *eta = [NSDate dateWithTimeIntervalSince1970:1704067200.0]; // 2024-01-01 00:00 UTC
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1704063600.0]; // -1h
    NSDate *end = [NSDate dateWithTimeIntervalSince1970:1704070800.0];   // +1h

    NSString *result = [CMMatchExplanation timeFitExplanationWithETA:eta
                                                         windowStart:start
                                                           windowEnd:end];
    XCTAssertNotNil(result);
    XCTAssertTrue([result containsString:@"window"],
                  @"Time fit explanation should mention the window");
}

- (void)testTimeFitExplanation_WithNilETA {
    NSDate *start = [NSDate date];
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSString *result = [CMMatchExplanation timeFitExplanationWithETA:nil
                                                         windowStart:start
                                                           windowEnd:end];
    XCTAssertEqualObjects(result, @"time fit data unavailable");
}

- (void)testTimeFitExplanation_WithNilWindowStart {
    NSDate *eta = [NSDate date];
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:3600];
    NSString *result = [CMMatchExplanation timeFitExplanationWithETA:eta
                                                         windowStart:nil
                                                           windowEnd:end];
    XCTAssertEqualObjects(result, @"time fit data unavailable");
}

- (void)testTimeFitExplanation_WithNilWindowEnd {
    NSDate *eta = [NSDate date];
    NSDate *start = [NSDate date];
    NSString *result = [CMMatchExplanation timeFitExplanationWithETA:eta
                                                         windowStart:start
                                                           windowEnd:nil];
    XCTAssertEqualObjects(result, @"time fit data unavailable");
}

#pragma mark - detourExplanationWithMiles

- (void)testDetourExplanation_PositiveMiles {
    NSString *result = [CMMatchExplanation detourExplanationWithMiles:5.3];
    XCTAssertNotNil(result);
    XCTAssertTrue([result containsString:@"5.3"], @"Should contain formatted miles");
    XCTAssertTrue([result containsString:@"mi detour"], @"Should mention detour");
}

- (void)testDetourExplanation_ZeroMiles {
    NSString *result = [CMMatchExplanation detourExplanationWithMiles:0.0];
    XCTAssertTrue([result containsString:@"0.0"], @"Zero miles should still be formatted");
}

@end
