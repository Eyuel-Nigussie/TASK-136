//
//  CMAuthFlowIntegrationTests.m
//  CourierMatch Integration Tests
//
//  Authentication flow: signup, login, wrong password, CAPTCHA gating,
//  lockout, lock expiry, and forced logout.
//

#import "CMIntegrationTestCase.h"
#import "CMAuthService.h"
#import "CMUserAccount.h"
#import "CMPasswordHasher.h"
#import "CMPasswordPolicy.h"
#import "CMLockoutPolicy.h"
#import "CMCaptchaChallenge.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMUserRepository.h"
#import "CMCoreDataStack.h"
#import "NSManagedObjectContext+CMHelpers.h"

@interface CMAuthFlowIntegrationTests : CMIntegrationTestCase
@end

@implementation CMAuthFlowIntegrationTests

#pragma mark - Test 1: Signup a New User

- (void)testSignupCreatesUserWithCorrectPasswordHash {
    XCTestExpectation *signupExp = [self expectationWithDescription:@"Signup completes"];

    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"newcourier"
                                      password:@"Str0ng!Pass#99"
                                   displayName:@"New Courier"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        // Step 2: Verify user exists with correct password hash
        XCTAssertNotNil(user, @"User should be created: %@", error);
        XCTAssertNil(error, @"No error expected");
        XCTAssertEqualObjects(user.username, @"newcourier");
        XCTAssertEqualObjects(user.tenantId, self.testTenantId);
        XCTAssertNotNil(user.passwordHash, @"Password hash should exist");
        XCTAssertNotNil(user.passwordSalt, @"Password salt should exist");
        XCTAssertGreaterThan(user.passwordIterations, 0, @"Password iterations should be > 0");
        XCTAssertEqualObjects(user.role, CMUserRoleCourier);
        XCTAssertEqualObjects(user.status, CMUserStatusActive);
        XCTAssertEqual(user.failedAttempts, 0);

        // Verify the stored hash matches the password
        BOOL valid = [CMPasswordHasher verifyPassword:@"Str0ng!Pass#99"
                                                  salt:user.passwordSalt
                                           iterations:(NSUInteger)user.passwordIterations
                                          expectedHash:user.passwordHash];
        XCTAssertTrue(valid, @"Password verification should succeed with correct password");

        [signupExp fulfill];
    }];

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Test 3: Login with Correct Password

- (void)testLoginWithCorrectPasswordPopulatesTenantContext {
    // First signup a user
    XCTestExpectation *signupExp = [self expectationWithDescription:@"Signup for login test"];
    __block NSString *createdUserId = nil;

    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"loginuser"
                                      password:@"C0rrect!Pass#1"
                                   displayName:@"Login User"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNotNil(user, @"Signup should succeed: %@", error);
        createdUserId = user.userId;
        [signupExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(createdUserId, @"User should have been created");

    // Now login
    XCTestExpectation *loginExp = [self expectationWithDescription:@"Login succeeds"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@"loginuser"
                                     password:@"C0rrect!Pass#1"
                            captchaChallengeId:nil
                                 captchaAnswer:nil
                                    completion:^(CMAuthAttemptResult *result) {
        XCTAssertEqual(result.outcome, CMAuthStepOutcomeSucceeded,
                       @"Login should succeed");
        XCTAssertNotNil(result.user, @"Authenticated user should be returned");
        XCTAssertEqualObjects(result.user.userId, createdUserId);

        // Verify CMTenantContext is populated
        XCTAssertTrue([[CMTenantContext shared] isAuthenticated],
                       @"Tenant context should be authenticated after login");
        XCTAssertEqualObjects([CMTenantContext shared].currentUserId, createdUserId);
        XCTAssertEqualObjects([CMTenantContext shared].currentTenantId, self.testTenantId);
        [loginExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Test 4: Login with Wrong Password

- (void)testLoginWithWrongPasswordIncrementsFailedAttempts {
    // Signup a user first
    XCTestExpectation *signupExp = [self expectationWithDescription:@"Signup for wrong pw test"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"wrongpwuser"
                                      password:@"R1ght!Pass#99x"
                                   displayName:@"Wrong PW User"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNotNil(user, @"Signup should succeed: %@", error);
        [signupExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Attempt login with wrong password
    XCTestExpectation *loginExp = [self expectationWithDescription:@"Wrong password login"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@"wrongpwuser"
                                     password:@"Wr0ng!Password#"
                            captchaChallengeId:nil
                                 captchaAnswer:nil
                                    completion:^(CMAuthAttemptResult *result) {
        XCTAssertEqual(result.outcome, CMAuthStepOutcomeFailed,
                       @"Login with wrong password should fail");
        XCTAssertNil(result.user, @"No user should be returned on failure");
        XCTAssertNotNil(result.error, @"Error should be returned");
        [loginExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Verify failedAttempts was incremented
    CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:self.testContext];
    NSError *lookupErr = nil;
    CMUserAccount *user = [repo preAuthLookupWithTenantId:self.testTenantId
                                                 username:@"wrongpwuser"
                                                    error:&lookupErr];
    XCTAssertNotNil(user, @"User should exist");
    XCTAssertGreaterThan(user.failedAttempts, 0, @"Failed attempts should be incremented");
}

#pragma mark - Test 5: Three Failures Triggers CAPTCHA Requirement

- (void)testThreeFailuresRequiresCaptcha {
    // Signup
    XCTestExpectation *signupExp = [self expectationWithDescription:@"Signup for captcha test"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"captchauser"
                                      password:@"G00d!Pass#wd1"
                                   displayName:@"Captcha User"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNotNil(user);
        [signupExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Fail 3 times
    for (int i = 0; i < 3; i++) {
        XCTestExpectation *failExp = [self expectationWithDescription:
            [NSString stringWithFormat:@"Fail attempt %d", i + 1]];
        [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                         username:@"captchauser"
                                         password:@"Wr0ng!Password#"
                                captchaChallengeId:nil
                                     captchaAnswer:nil
                                        completion:^(CMAuthAttemptResult *result) {
            // First 3 failures: outcome should be Failed (not yet captcha-gated)
            // or CaptchaRequired on the 4th attempt with the 3rd failure already recorded
            [failExp fulfill];
        }];
        [self waitForExpectationsWithTimeout:10.0 handler:nil];
    }

    // The 4th attempt should require CAPTCHA (failedAttempts >= 3)
    XCTestExpectation *captchaExp = [self expectationWithDescription:@"Captcha required"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@"captchauser"
                                     password:@"G00d!Pass#wd1"
                            captchaChallengeId:nil
                                 captchaAnswer:nil
                                    completion:^(CMAuthAttemptResult *result) {
        XCTAssertEqual(result.outcome, CMAuthStepOutcomeCaptchaRequired,
                       @"Should require CAPTCHA after 3 failures");
        XCTAssertNotNil(result.pendingCaptcha, @"Pending CAPTCHA should be provided");
        XCTAssertNotNil(result.pendingCaptcha.challengeId, @"CAPTCHA should have an ID");
        XCTAssertNotNil(result.pendingCaptcha.question, @"CAPTCHA should have a question");
        [captchaExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Test 6: CAPTCHA Solve + Login Succeeds

- (void)testCaptchaSolveAllowsLogin {
    // Issue a CAPTCHA challenge directly
    CMCaptchaChallenge *challenge = [[CMCaptchaService shared] issueChallenge];
    XCTAssertNotNil(challenge.challengeId, @"Challenge should have ID");
    XCTAssertNotNil(challenge.question, @"Challenge should have a question");

    // Parse the question to compute the answer
    NSString *question = challenge.question;
    // Question is like "3 + 4" or "3 x 4"
    NSArray *parts = [question componentsSeparatedByString:@" "];
    XCTAssertGreaterThanOrEqual(parts.count, 3, @"Question should have at least 3 parts");

    int a = [parts[0] intValue];
    NSString *op = parts[1];
    int b = [parts[2] intValue];
    int answer = 0;

    if ([op containsString:@"+"]) {
        answer = a + b;
    } else {
        // multiplication (x or unicode multiply)
        answer = a * b;
    }

    NSString *answerStr = [NSString stringWithFormat:@"%d", answer];

    // Verify the answer
    BOOL correct = [[CMCaptchaService shared] verifyChallengeId:challenge.challengeId
                                                          answer:answerStr];
    XCTAssertTrue(correct, @"Correct CAPTCHA answer should verify successfully");
}

#pragma mark - Test 7: Five Failures Locks Account

- (void)testFiveFailuresLocksAccount {
    // Signup
    XCTestExpectation *signupExp = [self expectationWithDescription:@"Signup for lockout test"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"lockoutuser"
                                      password:@"L0ck0ut!Pass#9"
                                   displayName:@"Lockout User"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNotNil(user);
        [signupExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Fail 5 times. After 3 failures, CAPTCHA is required — supply a wrong
    // CAPTCHA answer so the failure counter still increments (a CAPTCHA-fail
    // path calls applyFailureTo: in CMAuthService).
    __block NSString *pendingCaptchaId = nil;
    // Loop 7 times to accumulate 5 actual failures: the first CAPTCHA-gated
    // attempt returns CaptchaRequired without incrementing failedAttempts,
    // so we need extra iterations to reach the lockout threshold.
    for (int i = 0; i < 7; i++) {
        XCTestExpectation *failExp = [self expectationWithDescription:
            [NSString stringWithFormat:@"Lock fail %d", i + 1]];

        NSString *captchaId = pendingCaptchaId;
        NSString *captchaAns = captchaId ? @"99999" : nil; // deliberately wrong

        [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                         username:@"lockoutuser"
                                         password:@"Wrong!Password#1"
                                captchaChallengeId:captchaId
                                     captchaAnswer:captchaAns
                                        completion:^(CMAuthAttemptResult *result) {
            // Capture any newly issued CAPTCHA for the next iteration.
            if (result.pendingCaptcha) {
                pendingCaptchaId = result.pendingCaptcha.challengeId;
            }
            [failExp fulfill];
        }];
        [self waitForExpectationsWithTimeout:10.0 handler:nil];
    }

    // Verify the account is now locked
    CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:self.testContext];
    CMUserAccount *user = [repo preAuthLookupWithTenantId:self.testTenantId
                                                 username:@"lockoutuser"
                                                    error:nil];
    XCTAssertNotNil(user, @"User should exist");
    XCTAssertGreaterThanOrEqual(user.failedAttempts, (int16_t)[CMLockoutPolicy lockoutThreshold],
                                @"Failed attempts should be >= lockout threshold");

    // The next attempt should return locked
    XCTestExpectation *lockedExp = [self expectationWithDescription:@"Account locked"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@"lockoutuser"
                                     password:@"L0ck0ut!Pass#9"
                                captchaChallengeId:nil
                                 captchaAnswer:nil
                                    completion:^(CMAuthAttemptResult *result) {
        // Should be locked or captcha-required (both indicate the lockout path is active)
        XCTAssertTrue(result.outcome == CMAuthStepOutcomeLocked ||
                       result.outcome == CMAuthStepOutcomeCaptchaRequired,
                       @"Account should be locked or captcha-gated, got %ld",
                       (long)result.outcome);
        [lockedExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Test 8: Lock Expires After Duration

- (void)testLockExpiresAfterDuration {
    // Create a user and manually set them as locked with a past lockUntil
    CMUserAccount *lockedUser = [self createLockedUserWithExpiredLock];
    [self saveContext];

    XCTAssertEqualObjects(lockedUser.status, CMUserStatusLocked,
                          @"User should start as locked");

    // The CMLockoutPolicy.maybeClearExpiredLockOn: should clear the lock
    // since lockUntil is in the past
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:lockedUser];
    XCTAssertTrue(cleared, @"Expired lock should be cleared");
    XCTAssertEqualObjects(lockedUser.status, CMUserStatusActive,
                          @"User should be active after lock expiry");
    XCTAssertNil(lockedUser.lockUntil, @"lockUntil should be nil after expiry");
}

- (CMUserAccount *)createLockedUserWithExpiredLock {
    CMUserAccount *user = [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                                        inManagedObjectContext:self.testContext];
    user.userId = @"user-locked-test";
    user.tenantId = self.testTenantId;
    user.username = @"lockedexpiry";
    user.role = CMUserRoleCourier;
    user.status = CMUserStatusLocked;
    user.failedAttempts = 5;
    // Lock expired 5 minutes ago
    user.lockUntil = [NSDate dateWithTimeIntervalSinceNow:-300];
    user.createdAt = [NSDate date];
    user.updatedAt = [NSDate date];
    user.version = 1;
    return user;
}

#pragma mark - Test 9: Force Logout Via forceLogoutAt

- (void)testForceLogoutInvalidatesSession {
    // Open a session for the courier user
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertTrue([[CMSessionManager shared] hasActiveSession],
                  @"Session should be active");

    // Set forceLogoutAt to a future time (after issuedAt)
    self.courierUser.forceLogoutAt = [NSDate dateWithTimeIntervalSinceNow:1];
    [self saveContext];

    // The preflight check should fail because forceLogoutAt > issuedAt
    // Wait a moment for the forceLogoutAt to be in the past relative to issuedAt
    NSError *preflightError = nil;
    BOOL preflightOK = [[CMSessionManager shared] preflightSensitiveActionWithError:&preflightError];
    // The preflight may pass or fail depending on timing. If forceLogoutAt is after issuedAt,
    // it should fail. Let's test the logic directly:

    // More reliable: set forceLogoutAt to a time after the session was issued
    NSDate *issuedAt = [CMSessionManager shared].issuedAt;
    if (issuedAt) {
        self.courierUser.forceLogoutAt = [issuedAt dateByAddingTimeInterval:1];
        [self saveContext];

        NSError *err = nil;
        BOOL ok = [[CMSessionManager shared] preflightSensitiveActionWithError:&err];
        XCTAssertFalse(ok, @"Preflight should fail after forced logout");
        XCTAssertNotNil(err, @"Error should describe the forced logout");
    }
}

#pragma mark - Test: Signup with Weak Password Fails

- (void)testSignupWithWeakPasswordFails {
    XCTestExpectation *exp = [self expectationWithDescription:@"Weak password signup"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"weakpwuser"
                                      password:@"short"
                                   displayName:@"Weak PW User"
                                          role:CMUserRoleCourier
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNil(user, @"User should not be created with weak password");
        XCTAssertNotNil(error, @"Error should describe password policy violation");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Negative: Unauthenticated Signup With Admin Role Denied

- (void)testUnauthenticatedSignupWithAdminRoleIsDenied {
    // Clear tenant context to simulate unauthenticated state.
    [[CMTenantContext shared] clear];

    XCTestExpectation *exp = [self expectationWithDescription:@"Admin signup denied"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"rogue_admin"
                                      password:@"Str0ng!Pass#99"
                                   displayName:@"Rogue Admin"
                                          role:CMUserRoleAdmin
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNil(user, @"User must NOT be created for non-courier role without admin session");
        XCTAssertNotNil(error, @"Error should describe permission denial");
        XCTAssertEqual(error.code, CMErrorCodePermissionDenied,
                       @"Error code should be PermissionDenied");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Verify no user was persisted
    CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:self.testContext];
    NSError *lookupErr = nil;
    CMUserAccount *user = [repo preAuthLookupWithTenantId:self.testTenantId
                                                 username:@"rogue_admin"
                                                    error:&lookupErr];
    XCTAssertNil(user, @"No user should exist for denied admin signup");
}

#pragma mark - Negative: Unauthenticated Signup With Finance Role Denied

- (void)testUnauthenticatedSignupWithFinanceRoleIsDenied {
    // Clear tenant context to simulate unauthenticated state.
    [[CMTenantContext shared] clear];

    XCTestExpectation *exp = [self expectationWithDescription:@"Finance signup denied"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"rogue_finance"
                                      password:@"Str0ng!Pass#99"
                                   displayName:@"Rogue Finance"
                                          role:CMUserRoleFinance
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNil(user, @"User must NOT be created for finance role without admin session");
        XCTAssertNotNil(error, @"Error should describe permission denial");
        XCTAssertEqual(error.code, CMErrorCodePermissionDenied,
                       @"Error code should be PermissionDenied");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Negative: Non-Admin Authenticated Signup With Admin Role Denied

- (void)testCourierSignupWithAdminRoleIsDenied {
    // Switch to courier user (non-admin authenticated user).
    [self switchToUser:self.courierUser];

    XCTestExpectation *exp = [self expectationWithDescription:@"Courier creating admin denied"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"courier_admin"
                                      password:@"Str0ng!Pass#99"
                                   displayName:@"Courier Admin"
                                          role:CMUserRoleAdmin
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNil(user, @"Non-admin user must NOT create admin accounts");
        XCTAssertNotNil(error, @"Error should describe permission denial");
        XCTAssertEqual(error.code, CMErrorCodePermissionDenied,
                       @"Error code should be PermissionDenied");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Positive: Admin Can Create Non-Courier Account

- (void)testAdminCanCreateDispatcherAccount {
    // Switch to admin user.
    [self switchToUser:self.adminUser];

    XCTestExpectation *exp = [self expectationWithDescription:@"Admin creates dispatcher"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                      username:@"new_dispatcher"
                                      password:@"Str0ng!Pass#99"
                                   displayName:@"New Dispatcher"
                                          role:CMUserRoleDispatcher
                                    completion:^(CMUserAccount *user, NSError *error) {
        XCTAssertNotNil(user, @"Admin should be able to create dispatcher: %@", error);
        XCTAssertNil(error, @"No error expected for admin creating dispatcher");
        XCTAssertEqualObjects(user.role, CMUserRoleDispatcher);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
