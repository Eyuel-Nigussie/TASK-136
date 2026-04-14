//
//  CMIDMaskerTests.m
//  CourierMatch
//
//  Unit tests for CMIDMasker — sensitive data masking per design.md S8.
//

#import <XCTest/XCTest.h>
#import "CMIDMasker.h"

@interface CMIDMaskerTests : XCTestCase
@end

@implementation CMIDMaskerTests

#pragma mark - ssnStyle

- (void)testSSN_FullNineDigits_MasksCorrectly {
    NSString *masked = [CMIDMasker ssnStyle:@"123456789"];
    XCTAssertEqualObjects(masked, @"***-**-6789");
}

- (void)testSSN_WithDashes_MasksCorrectly {
    NSString *masked = [CMIDMasker ssnStyle:@"123-45-6789"];
    XCTAssertEqualObjects(masked, @"***-**-6789");
}

- (void)testSSN_FewerThan4Digits_ReturnsFullMask {
    NSString *masked = [CMIDMasker ssnStyle:@"12"];
    XCTAssertEqualObjects(masked, @"***-**-****");
}

- (void)testSSN_ExactlyFourDigits_ShowsAll {
    NSString *masked = [CMIDMasker ssnStyle:@"1234"];
    XCTAssertEqualObjects(masked, @"***-**-1234");
}

- (void)testSSN_Nil_ReturnsEmpty {
    NSString *masked = [CMIDMasker ssnStyle:nil];
    XCTAssertEqualObjects(masked, @"");
}

#pragma mark - emailStyle

- (void)testEmail_Standard_MasksLocal {
    NSString *masked = [CMIDMasker emailStyle:@"user@domain.com"];
    XCTAssertEqualObjects(masked, @"****@domain.com");
}

- (void)testEmail_WithoutAtSign_ReturnsMask {
    NSString *masked = [CMIDMasker emailStyle:@"noemailhere"];
    XCTAssertEqualObjects(masked, @"****");
}

- (void)testEmail_MultipleAts_UsesFirstAt {
    // Implementation uses rangeOfString:@"@" which finds the first occurrence.
    NSString *masked = [CMIDMasker emailStyle:@"a@b@c"];
    XCTAssertEqualObjects(masked, @"****@b@c");
}

#pragma mark - phoneStyle

- (void)testPhone_TenDigits_MasksCorrectly {
    NSString *masked = [CMIDMasker phoneStyle:@"2125551234"];
    XCTAssertEqualObjects(masked, @"(***) ***-12-34");
}

- (void)testPhone_FormattedInput_MasksCorrectly {
    NSString *masked = [CMIDMasker phoneStyle:@"(212) 555-1234"];
    XCTAssertEqualObjects(masked, @"(***) ***-12-34");
}

- (void)testPhone_FewerThan4Digits_ReturnsFullMask {
    NSString *masked = [CMIDMasker phoneStyle:@"12"];
    XCTAssertEqualObjects(masked, @"(***) ***-**-**");
}

#pragma mark - maskTrailing

- (void)testMaskTrailing_Standard {
    NSString *masked = [CMIDMasker maskTrailing:@"ABCDEFGH" visibleTail:4];
    XCTAssertEqualObjects(masked, @"****EFGH");
}

- (void)testMaskTrailing_TailEqualsLength_ReturnsOriginal {
    NSString *masked = [CMIDMasker maskTrailing:@"ABCD" visibleTail:4];
    XCTAssertEqualObjects(masked, @"ABCD");
}

- (void)testMaskTrailing_TailExceedsLength_ReturnsOriginal {
    NSString *masked = [CMIDMasker maskTrailing:@"AB" visibleTail:10];
    XCTAssertEqualObjects(masked, @"AB");
}

- (void)testMaskTrailing_TailZero_AllMasked {
    NSString *masked = [CMIDMasker maskTrailing:@"SECRET" visibleTail:0];
    XCTAssertEqualObjects(masked, @"******");
}

- (void)testMaskTrailing_Nil_ReturnsEmpty {
    NSString *masked = [CMIDMasker maskTrailing:nil visibleTail:4];
    XCTAssertEqualObjects(masked, @"");
}

- (void)testMaskTrailing_EmptyString_ReturnsEmpty {
    NSString *masked = [CMIDMasker maskTrailing:@"" visibleTail:4];
    XCTAssertEqualObjects(masked, @"");
}

@end
