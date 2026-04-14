//
//  CMZipMetroTableTests.m
//  CourierMatch Tests
//
//  Tests for metro ZIP lookup: metro/rural classification and multipliers.
//

#import <XCTest/XCTest.h>
#import "CMZipMetroTable.h"

@interface CMZipMetroTableTests : XCTestCase
@property (nonatomic, strong) CMZipMetroTable *table;
@end

@implementation CMZipMetroTableTests

- (void)setUp {
    [super setUp];
    self.table = [[CMZipMetroTable alloc] init];
}

#pragma mark - NYC ZIP prefix "100" isMetro YES

- (void)testNYCZipPrefixIsMetro {
    BOOL result = [self.table isMetroZip:@"10001"];
    XCTAssertTrue(result, @"NYC ZIP 10001 (prefix 100) should be metro");
}

#pragma mark - Rural ZIP prefix "999" isMetro NO

- (void)testRuralZipPrefixIsNotMetro {
    BOOL result = [self.table isMetroZip:@"99901"];
    XCTAssertFalse(result, @"ZIP 99901 (prefix 999) should not be metro");
}

#pragma mark - areBothMetro: both metro YES, one metro NO

- (void)testAreBothMetroBothMetroYES {
    BOOL result = [self.table areBothMetroZip1:@"10001" zip2:@"10002"];
    XCTAssertTrue(result, @"Both NYC ZIPs should return YES for areBothMetro");
}

- (void)testAreBothMetroOnlyOneMetroNO {
    BOOL result = [self.table areBothMetroZip1:@"10001" zip2:@"99901"];
    XCTAssertFalse(result,
        @"One metro + one rural should return NO for areBothMetro");
}

#pragma mark - multiplierForBothMetro

- (void)testMultiplierForBothMetroYES {
    double m = [self.table multiplierForBothMetro:YES];
    XCTAssertEqualWithAccuracy(m, 1.35, 0.001,
        @"Urban multiplier should be 1.35 when both metro");
}

- (void)testMultiplierForBothMetroNO {
    double m = [self.table multiplierForBothMetro:NO];
    XCTAssertEqualWithAccuracy(m, 1.15, 0.001,
        @"Rural multiplier should be 1.15 when not both metro");
}

@end
