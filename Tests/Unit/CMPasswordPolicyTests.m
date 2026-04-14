//
//  CMPasswordPolicyTests.m
//  CourierMatch
//
//  Unit tests for CMPasswordPolicy — password validation rules per design.md S4.1.
//

#import <XCTest/XCTest.h>
#import "CMPasswordPolicy.h"

/// We allocate a fresh instance for each test so that we do not depend on the
/// singleton's plist-loaded blocklist (which requires the main bundle). Instead
/// we exercise the pure-logic paths directly.
@interface CMPasswordPolicy (Testing)
@property (nonatomic, strong) NSSet<NSString *> *blocklist;
@end

@interface CMPasswordPolicyTests : XCTestCase
@property (nonatomic, strong) CMPasswordPolicy *policy;
@end

@implementation CMPasswordPolicyTests

- (void)setUp {
    [super setUp];
    // Create a fresh, non-singleton instance so tests are isolated.
    self.policy = [[CMPasswordPolicy alloc] init];
    // Inject a small blocklist for deterministic testing.
    self.policy.blocklist = [NSSet setWithArray:@[
        @"Password1234!",
        @"P@ssw0rd1234!",
        @"Welcome12345!",
    ]];
}

- (void)tearDown {
    self.policy = nil;
    [super tearDown];
}

#pragma mark - Length

- (void)testValidPassword_12CharsDigitSymbol_ReturnsNone {
    // Exactly 12 characters, one digit, one symbol.
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefghij1!"];
    XCTAssertEqual(v, CMPasswordViolationNone, @"A 12-char password with digit and symbol should pass");
}

- (void)testPassword_11Chars_FailsWithTooShort {
    // 11 characters — just below the minimum.
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefghi1!"];
    XCTAssertTrue((v & CMPasswordViolationTooShort) != 0,
                  @"11-char password must trigger CMPasswordViolationTooShort");
}

- (void)testPassword_12CharsExact_Passes {
    CMPasswordViolation v = [self.policy evaluate:@"123456789ab!"];
    XCTAssertEqual(v, CMPasswordViolationNone);
}

- (void)testPassword_LongerThan12_Passes {
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefghijklmnopq1!"];
    XCTAssertEqual(v, CMPasswordViolationNone);
}

#pragma mark - Missing digit

- (void)testPassword_MissingDigit_FailsWithMissingDigit {
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefghijk!"];
    XCTAssertTrue((v & CMPasswordViolationMissingDigit) != 0,
                  @"Password without a digit should fail with MissingDigit");
    // Should not trigger TooShort (12 chars).
    XCTAssertFalse((v & CMPasswordViolationTooShort) != 0);
}

#pragma mark - Missing symbol

- (void)testPassword_MissingSymbol_FailsWithMissingSymbol {
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefghijk1"];
    XCTAssertTrue((v & CMPasswordViolationMissingSymbol) != 0,
                  @"Password without a symbol should fail with MissingSymbol");
    XCTAssertFalse((v & CMPasswordViolationTooShort) != 0);
}

#pragma mark - Blocklist

- (void)testPassword_OnBlocklist_FailsWithBlocklisted {
    CMPasswordViolation v = [self.policy evaluate:@"Password1234!"];
    XCTAssertTrue((v & CMPasswordViolationBlocklisted) != 0,
                  @"Blocklisted password should trigger CMPasswordViolationBlocklisted");
}

- (void)testPassword_NotOnBlocklist_DoesNotFlagBlocklisted {
    CMPasswordViolation v = [self.policy evaluate:@"UniqueStr0ng!"];
    XCTAssertFalse((v & CMPasswordViolationBlocklisted) != 0);
}

#pragma mark - Multiple violations (bitmask)

- (void)testPassword_MultipleViolations_ReturnedAsBitmask {
    // 5 characters, no digit, no symbol.
    CMPasswordViolation v = [self.policy evaluate:@"abcde"];
    XCTAssertTrue((v & CMPasswordViolationTooShort) != 0);
    XCTAssertTrue((v & CMPasswordViolationMissingDigit) != 0);
    XCTAssertTrue((v & CMPasswordViolationMissingSymbol) != 0);
}

- (void)testPassword_ShortAndMissingDigit_Bitmask {
    // 8 chars with symbol but no digit.
    CMPasswordViolation v = [self.policy evaluate:@"Abcdefg!"];
    XCTAssertTrue((v & CMPasswordViolationTooShort) != 0);
    XCTAssertTrue((v & CMPasswordViolationMissingDigit) != 0);
    XCTAssertFalse((v & CMPasswordViolationMissingSymbol) != 0);
}

#pragma mark - Empty / nil

- (void)testPassword_Nil_ReturnsEmpty {
    CMPasswordViolation v = [self.policy evaluate:nil];
    XCTAssertEqual(v, CMPasswordViolationEmpty,
                   @"nil password must return CMPasswordViolationEmpty");
}

- (void)testPassword_EmptyString_ReturnsEmpty {
    CMPasswordViolation v = [self.policy evaluate:@""];
    XCTAssertEqual(v, CMPasswordViolationEmpty,
                   @"Empty string must return CMPasswordViolationEmpty");
}

#pragma mark - Valid passwords

- (void)testPassword_FullyValid_ReturnsNone {
    CMPasswordViolation v = [self.policy evaluate:@"C0mpl3x!Pass"];
    XCTAssertEqual(v, CMPasswordViolationNone,
                   @"Valid password (12+ chars, digit, symbol, not blocklisted) should return None");
}

#pragma mark - summaryForViolations:

- (void)testSummary_None_ReturnsEmptyString {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationNone];
    XCTAssertEqualObjects(s, @"");
}

- (void)testSummary_Empty_ContainsEmptyMessage {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationEmpty];
    XCTAssertTrue([s containsString:@"Password is empty"]);
}

- (void)testSummary_TooShort_ContainsLengthMessage {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationTooShort];
    XCTAssertTrue([s containsString:@"at least 12 characters"],
                  @"Expected length guidance, got: %@", s);
}

- (void)testSummary_MissingDigit_ContainsDigitMessage {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationMissingDigit];
    XCTAssertTrue([s containsString:@"digit"]);
}

- (void)testSummary_MissingSymbol_ContainsSymbolMessage {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationMissingSymbol];
    XCTAssertTrue([s containsString:@"symbol"]);
}

- (void)testSummary_Blocklisted_ContainsBlocklistMessage {
    NSString *s = [self.policy summaryForViolations:CMPasswordViolationBlocklisted];
    XCTAssertTrue([s containsString:@"Too common"]);
}

- (void)testSummary_MultipleViolations_SemicolonSeparated {
    CMPasswordViolation combo = CMPasswordViolationTooShort | CMPasswordViolationMissingDigit;
    NSString *s = [self.policy summaryForViolations:combo];
    XCTAssertTrue([s containsString:@";"]);
    XCTAssertTrue([s containsString:@"at least 12 characters"]);
    XCTAssertTrue([s containsString:@"digit"]);
}

#pragma mark - Minimum length property

- (void)testMinimumLength_DefaultIs12 {
    XCTAssertEqual(self.policy.minimumLength, 12u);
}

#pragma mark - Symbol class

- (void)testSymbolClass_AlphanumericDoesNotCount {
    // 'A' is alphanumeric — not a symbol.
    XCTAssertFalse([self.policy.symbolClass characterIsMember:'A']);
    XCTAssertFalse([self.policy.symbolClass characterIsMember:'0']);
}

- (void)testSymbolClass_SpecialCharsCount {
    XCTAssertTrue([self.policy.symbolClass characterIsMember:'!']);
    XCTAssertTrue([self.policy.symbolClass characterIsMember:'@']);
    XCTAssertTrue([self.policy.symbolClass characterIsMember:'#']);
}

@end
