//
//  CMAddressTests.m
//  CourierMatch Tests
//

#import <XCTest/XCTest.h>
#import "CMAddress.h"

@interface CMAddressTests : XCTestCase
@end

@implementation CMAddressTests

- (CMAddress *)sampleAddress {
    CMAddress *a = [[CMAddress alloc] init];
    a.line1 = @"123 Main St";
    a.line2 = @"Apt 4B";
    a.city = @"New York";
    a.stateAbbr = @"NY";
    a.zip = @"10001";
    a.lat = 40.7128;
    a.lng = -74.0060;
    a.normalizedKey = @"123 main st|new york|ny|10001";
    return a;
}

- (void)testInitialization {
    CMAddress *a = [[CMAddress alloc] init];
    XCTAssertNotNil(a);
}

- (void)testToDictionaryRoundtrip {
    CMAddress *a = [self sampleAddress];
    NSDictionary *dict = [a toDictionary];
    XCTAssertNotNil(dict);
    XCTAssertEqualObjects(dict[@"line1"], @"123 Main St");
    XCTAssertEqualObjects(dict[@"city"], @"New York");
    XCTAssertEqualObjects(dict[@"zip"], @"10001");

    CMAddress *back = [CMAddress fromDictionary:dict];
    XCTAssertNotNil(back);
    XCTAssertEqualObjects(back.line1, a.line1);
    XCTAssertEqualObjects(back.city, a.city);
    XCTAssertEqualObjects(back.stateAbbr, a.stateAbbr);
    XCTAssertEqualObjects(back.zip, a.zip);
    XCTAssertEqualWithAccuracy(back.lat, a.lat, 0.0001);
    XCTAssertEqualWithAccuracy(back.lng, a.lng, 0.0001);
}

- (void)testFromDictionaryWithMinimalData {
    NSDictionary *dict = @{@"city": @"Boston", @"stateAbbr": @"MA"};
    CMAddress *a = [CMAddress fromDictionary:dict];
    XCTAssertNotNil(a);
    XCTAssertEqualObjects(a.city, @"Boston");
}

- (void)testCopying {
    CMAddress *a = [self sampleAddress];
    CMAddress *b = [a copy];
    XCTAssertNotNil(b);
    XCTAssertNotEqual(a, b, @"Should be a different instance");
    XCTAssertEqualObjects(a.line1, b.line1);
    XCTAssertEqualObjects(a.zip, b.zip);
}

- (void)testSecureCoding {
    XCTAssertTrue([CMAddress supportsSecureCoding]);

    CMAddress *original = [self sampleAddress];
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original
                                         requiringSecureCoding:YES error:&err];
    XCTAssertNotNil(data);
    XCTAssertNil(err);

    CMAddress *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMAddress class]
                                                           fromData:data error:&err];
    XCTAssertNotNil(decoded);
    XCTAssertEqualObjects(decoded.line1, original.line1);
    XCTAssertEqualObjects(decoded.city, original.city);
    XCTAssertEqualWithAccuracy(decoded.lat, original.lat, 0.0001);
}

- (void)testNilFieldsHandled {
    CMAddress *a = [[CMAddress alloc] init];
    XCTAssertNoThrow([a toDictionary]);
}

@end
