//
//  CMTimeZoneResolverTests.m
//  CourierMatch
//
//  Unit tests for CMTimeZoneResolver — ZIP prefix to timezone mapping per Q15.
//
//  NOTE: CMTimeZoneResolver loads ZipToTimeZone.plist from the main bundle.
//  In unit-test targets where the bundle does not include this plist, the map
//  will be empty. We therefore use a fresh instance and inject test data.
//

#import <XCTest/XCTest.h>
#import "CMTimeZoneResolver.h"

/// Expose internals so we can inject a known map for testing.
@interface CMTimeZoneResolver (Testing)
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *map;
@property (nonatomic, copy) NSString *fallbackId;
@end

@interface CMTimeZoneResolverTests : XCTestCase
@property (nonatomic, strong) CMTimeZoneResolver *resolver;
@end

@implementation CMTimeZoneResolverTests

- (void)setUp {
    [super setUp];
    self.resolver = [[CMTimeZoneResolver alloc] init];
    // Inject a known map so tests are deterministic regardless of the bundle.
    self.resolver.map = @{
        @"default": @"America/New_York",
        @"900":     @"America/Los_Angeles",
        @"100":     @"America/New_York",
        @"600":     @"America/Chicago",
        @"800":     @"America/Denver",
        @"967":     @"Pacific/Honolulu",
    };
    self.resolver.fallbackId = @"America/New_York";
}

- (void)tearDown {
    self.resolver = nil;
    [super tearDown];
}

#pragma mark - identifierForZip

- (void)testKnownZipPrefix900_LosAngeles {
    NSString *tz = [self.resolver identifierForZip:@"90001"];
    XCTAssertEqualObjects(tz, @"America/Los_Angeles");
}

- (void)testKnownZipPrefix100_NewYork {
    NSString *tz = [self.resolver identifierForZip:@"10001"];
    XCTAssertEqualObjects(tz, @"America/New_York");
}

- (void)testKnownZipPrefix600_Chicago {
    NSString *tz = [self.resolver identifierForZip:@"60001"];
    XCTAssertEqualObjects(tz, @"America/Chicago");
}

- (void)testUnknownZipPrefix_ReturnsNil {
    NSString *tz = [self.resolver identifierForZip:@"55555"];
    XCTAssertNil(tz, @"Unknown prefix should return nil from identifierForZip");
}

#pragma mark - timeZoneForZip

- (void)testTimeZoneForKnownZip_ReturnsExpected {
    NSTimeZone *tz = [self.resolver timeZoneForZip:@"90001"];
    XCTAssertNotNil(tz);
    XCTAssertEqualObjects(tz.name, @"America/Los_Angeles");
}

- (void)testTimeZoneForUnknownZip_ReturnsFallback {
    NSTimeZone *tz = [self.resolver timeZoneForZip:@"55555"];
    XCTAssertNotNil(tz, @"Unknown ZIP must still return a non-nil timezone");
    // Falls back to "America/New_York" per our injected fallbackId.
    XCTAssertEqualObjects(tz.name, @"America/New_York");
}

#pragma mark - nil / short ZIP

- (void)testNilZip_ReturnsFallbackTimezone {
    NSTimeZone *tz = [self.resolver timeZoneForZip:nil];
    XCTAssertNotNil(tz, @"nil ZIP must return a non-nil timezone (fallback)");
}

- (void)testShortZip_ReturnsFallbackTimezone {
    NSTimeZone *tz = [self.resolver timeZoneForZip:@"12"];
    XCTAssertNotNil(tz, @"Short ZIP (< 3 chars) must return a non-nil timezone");
}

- (void)testNilZip_IdentifierReturnsNil {
    NSString *tz = [self.resolver identifierForZip:nil];
    XCTAssertNil(tz);
}

- (void)testEmptyZip_IdentifierReturnsNil {
    NSString *tz = [self.resolver identifierForZip:@""];
    XCTAssertNil(tz);
}

- (void)testTwoCharZip_IdentifierReturnsNil {
    NSString *tz = [self.resolver identifierForZip:@"12"];
    XCTAssertNil(tz);
}

#pragma mark - Edge cases

- (void)testExactlyThreeCharZip_LooksUpPrefix {
    NSString *tz = [self.resolver identifierForZip:@"900"];
    XCTAssertEqualObjects(tz, @"America/Los_Angeles");
}

@end
