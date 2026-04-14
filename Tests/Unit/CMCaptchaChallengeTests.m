//
//  CMCaptchaChallengeTests.m
//  CourierMatch
//
//  Unit tests for CMCaptchaService — arithmetic CAPTCHA gate per Q10.
//

#import <XCTest/XCTest.h>
#import "CMCaptchaChallenge.h"

@interface CMCaptchaChallengeTests : XCTestCase
@property (nonatomic, strong) CMCaptchaService *service;
@end

/// Expose internals so we can manipulate expiresAt for expiration tests.
@interface CMCaptchaChallenge (Testing)
@property (nonatomic, strong, readwrite) NSDate *expiresAt;
@property (nonatomic, assign) BOOL consumed;
@end

/// Expose active dictionary for sweep testing.
@interface CMCaptchaService (Testing)
@property (nonatomic, strong) NSMutableDictionary<NSString *, CMCaptchaChallenge *> *active;
@end

@implementation CMCaptchaChallengeTests

- (void)setUp {
    [super setUp];
    // Fresh non-singleton service per test.
    self.service = [[CMCaptchaService alloc] init];
}

- (void)tearDown {
    self.service = nil;
    [super tearDown];
}

#pragma mark - issueChallenge

- (void)testIssueChallenge_ReturnsNonNilChallenge {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    XCTAssertNotNil(c);
    XCTAssertNotNil(c.challengeId);
    XCTAssertTrue(c.challengeId.length > 0);
}

- (void)testIssueChallenge_HasQuestionString {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    XCTAssertNotNil(c.question);
    XCTAssertTrue(c.question.length > 0);
}

- (void)testIssueChallenge_ExpiresAtIsInTheFuture {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    XCTAssertNotNil(c.expiresAt);
    XCTAssertTrue([c.expiresAt timeIntervalSinceNow] > 0,
                  @"expiresAt should be in the future");
}

#pragma mark - Verify with correct answer

- (void)testVerify_CorrectAnswer_ReturnsYES {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    NSString *answer = [self solveQuestion:c.question];
    BOOL result = [self.service verifyChallengeId:c.challengeId answer:answer];
    XCTAssertTrue(result, @"Correct answer should verify successfully");
}

#pragma mark - Verify with incorrect answer

- (void)testVerify_IncorrectAnswer_ReturnsNO {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    BOOL result = [self.service verifyChallengeId:c.challengeId answer:@"999999"];
    XCTAssertFalse(result, @"Incorrect answer should fail verification");
}

#pragma mark - Single-use

- (void)testVerify_SecondAttempt_ReturnsNO {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    NSString *answer = [self solveQuestion:c.question];
    BOOL first = [self.service verifyChallengeId:c.challengeId answer:answer];
    XCTAssertTrue(first);
    BOOL second = [self.service verifyChallengeId:c.challengeId answer:answer];
    XCTAssertFalse(second, @"Challenge must be single-use");
}

#pragma mark - Expired challenge

- (void)testVerify_ExpiredChallenge_ReturnsNO {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    NSString *answer = [self solveQuestion:c.question];
    // Force expiration by moving expiresAt into the past.
    c.expiresAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    BOOL result = [self.service verifyChallengeId:c.challengeId answer:answer];
    XCTAssertFalse(result, @"Expired challenge must fail verification");
}

#pragma mark - Nil / empty challengeId

- (void)testVerify_NilChallengeId_ReturnsNO {
    BOOL result = [self.service verifyChallengeId:nil answer:@"42"];
    XCTAssertFalse(result);
}

- (void)testVerify_EmptyChallengeId_ReturnsNO {
    BOOL result = [self.service verifyChallengeId:@"" answer:@"42"];
    XCTAssertFalse(result);
}

- (void)testVerify_UnknownChallengeId_ReturnsNO {
    BOOL result = [self.service verifyChallengeId:@"no-such-id" answer:@"42"];
    XCTAssertFalse(result);
}

#pragma mark - sweepExpired

- (void)testSweepExpired_RemovesOldChallenges {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    c.expiresAt = [NSDate dateWithTimeIntervalSinceNow:-10];
    XCTAssertTrue(self.service.active.count > 0);
    [self.service sweepExpired];
    XCTAssertNil(self.service.active[c.challengeId],
                 @"Expired challenge should have been swept");
}

- (void)testSweepExpired_KeepsValidChallenges {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    // expiresAt is still in the future by default.
    [self.service sweepExpired];
    XCTAssertNotNil(self.service.active[c.challengeId],
                    @"Valid challenge should survive sweep");
}

#pragma mark - Arithmetic correctness

- (void)testArithmeticAnswers_AreCorrect {
    // Issue many challenges and verify every single one can be solved.
    for (int i = 0; i < 50; i++) {
        CMCaptchaChallenge *c = [self.service issueChallenge];
        NSString *answer = [self solveQuestion:c.question];
        XCTAssertNotNil(answer, @"Failed to parse question: %@", c.question);
        BOOL ok = [self.service verifyChallengeId:c.challengeId answer:answer];
        XCTAssertTrue(ok, @"Computed answer '%@' should be correct for '%@'", answer, c.question);
    }
}

- (void)testQuestionFormat_ContainsOperator {
    CMCaptchaChallenge *c = [self.service issueChallenge];
    BOOL hasPlus = [c.question containsString:@"+"];
    BOOL hasMul  = [c.question containsString:@"\u00D7"]; // multiplication sign
    XCTAssertTrue(hasPlus || hasMul,
                  @"Question should contain + or multiplication sign, got: %@", c.question);
}

#pragma mark - Helper: solve arithmetic question

/// Parses "N + M" or "N x M" and returns the string answer.
- (NSString *)solveQuestion:(NSString *)q {
    if (!q) return nil;
    // Try addition.
    NSArray *addParts = [q componentsSeparatedByString:@" + "];
    if (addParts.count == 2) {
        int a = [addParts[0] intValue];
        int b = [addParts[1] intValue];
        return [NSString stringWithFormat:@"%d", a + b];
    }
    // Try multiplication (Unicode multiplication sign U+00D7).
    NSArray *mulParts = [q componentsSeparatedByString:@" \u00D7 "];
    if (mulParts.count == 2) {
        int a = [mulParts[0] intValue];
        int b = [mulParts[1] intValue];
        return [NSString stringWithFormat:@"%d", a * b];
    }
    return nil;
}

@end
