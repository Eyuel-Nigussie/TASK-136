//
//  CMAddressNormalizerTests.m
//  CourierMatch
//
//  Unit tests for CMAddressNormalizer — address normalization per design.md S7.1.
//
//  NOTE: CMAddressNormalizer loads USStateAbbreviations.plist from the main
//  bundle. In unit-test targets where the bundle does not include this plist,
//  the state map will be empty and tests for full-name -> abbreviation conversion
//  will see nil. To handle this, we also test the code through a fresh instance
//  that manually supplies state data if the plist is not available.
//

#import <XCTest/XCTest.h>
#import "CMAddressNormalizer.h"

/// Expose internals so we can inject state data for deterministic testing.
@interface CMAddressNormalizer (Testing)
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *stateMap;
@property (nonatomic, strong) NSSet<NSString *> *abbrSet;
@end

@interface CMAddressNormalizerTests : XCTestCase
@property (nonatomic, strong) CMAddressNormalizer *normalizer;
@end

@implementation CMAddressNormalizerTests

- (void)setUp {
    [super setUp];
    // Create a fresh instance (not the singleton) so we can inject test data.
    self.normalizer = [[CMAddressNormalizer alloc] init];
    // Inject a deterministic state map (in case the plist is missing from the
    // test bundle).
    NSDictionary *states = @{
        @"california":  @"CA",
        @"new york":    @"NY",
        @"texas":       @"TX",
        @"florida":     @"FL",
        @"illinois":    @"IL",
    };
    self.normalizer.stateMap = states;
    self.normalizer.abbrSet = [NSSet setWithArray:states.allValues];
}

- (void)tearDown {
    self.normalizer = nil;
    [super tearDown];
}

#pragma mark - stateAbbrFromInput

- (void)testStateAbbr_FullName_California {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"california"];
    XCTAssertEqualObjects(abbr, @"CA");
}

- (void)testStateAbbr_FullName_NewYork {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"new york"];
    XCTAssertEqualObjects(abbr, @"NY");
}

- (void)testStateAbbr_AlreadyAbbreviated_TX {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"TX"];
    XCTAssertEqualObjects(abbr, @"TX");
}

- (void)testStateAbbr_LowercaseAbbreviation_FL {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"fl"];
    XCTAssertEqualObjects(abbr, @"FL");
}

- (void)testStateAbbr_UnknownState_ReturnsNil {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"Narnia"];
    XCTAssertNil(abbr);
}

- (void)testStateAbbr_Nil_ReturnsNil {
    NSString *abbr = [self.normalizer stateAbbrFromInput:nil];
    XCTAssertNil(abbr);
}

- (void)testStateAbbr_EmptyString_ReturnsNil {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@""];
    XCTAssertNil(abbr);
}

- (void)testStateAbbr_WhitespaceOnly_ReturnsNil {
    NSString *abbr = [self.normalizer stateAbbrFromInput:@"   "];
    XCTAssertNil(abbr);
}

#pragma mark - isValidZip

- (void)testValidZip_FiveDigits {
    XCTAssertTrue([self.normalizer isValidZip:@"12345"]);
}

- (void)testValidZip_FivePlusFour {
    XCTAssertTrue([self.normalizer isValidZip:@"12345-6789"]);
}

- (void)testInvalidZip_FourDigits {
    XCTAssertFalse([self.normalizer isValidZip:@"1234"]);
}

- (void)testInvalidZip_Letters {
    XCTAssertFalse([self.normalizer isValidZip:@"ABCDE"]);
}

- (void)testInvalidZip_SixDigits {
    XCTAssertFalse([self.normalizer isValidZip:@"123456"]);
}

- (void)testInvalidZip_Nil {
    XCTAssertFalse([self.normalizer isValidZip:nil]);
}

- (void)testValidZip_WithLeadingWhitespace {
    XCTAssertTrue([self.normalizer isValidZip:@"  12345  "]);
}

#pragma mark - normalize

- (void)testNormalize_ProducesCorrectKey {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"123 Main St"
                                                       line2:nil
                                                        city:@"new york"
                                                       state:@"new york"
                                                         zip:@"10001"];
    XCTAssertNotNil(a);
    XCTAssertEqualObjects(a.normalizedKey, @"123 main st|new york|ny|10001");
}

- (void)testNormalize_CityIsTitleCased {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"1 First Ave"
                                                       line2:nil
                                                        city:@"new york"
                                                       state:@"NY"
                                                         zip:@"10001"];
    XCTAssertEqualObjects(a.city, @"New York");
}

- (void)testNormalize_WhitespaceTrimmed {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"  123 Main St  "
                                                       line2:@"  Apt 4  "
                                                        city:@"  new york  "
                                                       state:@"  NY  "
                                                         zip:@"  10001  "];
    XCTAssertNotNil(a);
    XCTAssertEqualObjects(a.line1, @"123 Main St");
    XCTAssertEqualObjects(a.line2, @"Apt 4");
    XCTAssertEqualObjects(a.zip, @"10001");
}

- (void)testNormalize_NilState_ReturnsNil {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"123 Main St"
                                                       line2:nil
                                                        city:@"Anytown"
                                                       state:nil
                                                         zip:@"12345"];
    XCTAssertNil(a);
}

- (void)testNormalize_InvalidZip_ReturnsNil {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"123 Main St"
                                                       line2:nil
                                                        city:@"Springfield"
                                                       state:@"IL"
                                                         zip:@"NOPE"];
    XCTAssertNil(a);
}

- (void)testNormalize_StateAbbr_SetCorrectly {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"1 Way"
                                                       line2:nil
                                                        city:@"Austin"
                                                       state:@"texas"
                                                         zip:@"73301"];
    XCTAssertNotNil(a);
    XCTAssertEqualObjects(a.stateAbbr, @"TX");
}

- (void)testNormalize_Zip5PlusFour_KeyUsesFirst5 {
    CMNormalizedAddress *a = [self.normalizer normalizeLine1:@"1 Way"
                                                       line2:nil
                                                        city:@"Chicago"
                                                       state:@"IL"
                                                         zip:@"60601-1234"];
    XCTAssertNotNil(a);
    XCTAssertTrue([a.normalizedKey hasSuffix:@"60601"]);
}

@end
