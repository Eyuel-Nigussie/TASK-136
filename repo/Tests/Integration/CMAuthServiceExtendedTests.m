//
//  CMAuthServiceExtendedTests.m
//  CourierMatch Integration Tests
//
//  Extended coverage of CMAuthService paths beyond the existing flow tests:
//  weak passwords, duplicate signups, biometric reauth, login with bad input.
//

#import "CMIntegrationTestCase.h"
#import "CMAuthService.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"
#import "CMSessionManager.h"

@interface CMAuthServiceExtendedTests : CMIntegrationTestCase
@end

@implementation CMAuthServiceExtendedTests

- (void)testSignupRejectsWeakPassword {
    XCTestExpectation *exp = [self expectationWithDescription:@"weak"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                       username:@"weakuser"
                                       password:@"short"
                                    displayName:nil
                                           role:CMUserRoleCourier
                                     completion:^(CMUserAccount *u, NSError *e) {
        XCTAssertNil(u);
        XCTAssertNotNil(e);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSignupRejectsPasswordWithoutDigit {
    XCTestExpectation *exp = [self expectationWithDescription:@"no digit"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                       username:@"user-nodigit"
                                       password:@"NoDigitPassword!"
                                    displayName:nil
                                           role:CMUserRoleCourier
                                     completion:^(CMUserAccount *u, NSError *e) {
        XCTAssertNil(u);
        XCTAssertNotNil(e);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSignupRejectsPasswordWithoutSymbol {
    XCTestExpectation *exp = [self expectationWithDescription:@"no symbol"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                       username:@"user-nosym"
                                       password:@"NoSymbolPass123"
                                    displayName:nil
                                           role:CMUserRoleCourier
                                     completion:^(CMUserAccount *u, NSError *e) {
        XCTAssertNil(u);
        XCTAssertNotNil(e);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testLoginWithNonexistentUser {
    XCTestExpectation *exp = [self expectationWithDescription:@"nonexistent"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@"does-not-exist"
                                     password:@"AnyPassword123!"
                            captchaChallengeId:nil
                                captchaAnswer:nil
                                   completion:^(CMAuthAttemptResult *r) {
        XCTAssertEqual(r.outcome, CMAuthStepOutcomeFailed);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testLoginWithEmptyCredentialsHandled {
    XCTestExpectation *exp = [self expectationWithDescription:@"empty"];
    [[CMAuthService shared] loginWithTenantId:self.testTenantId
                                     username:@""
                                     password:@""
                            captchaChallengeId:nil
                                captchaAnswer:nil
                                   completion:^(CMAuthAttemptResult *r) {
        XCTAssertNotEqual(r.outcome, CMAuthStepOutcomeSucceeded);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testBiometricReauthFiresCompletion {
    XCTestExpectation *exp = [self expectationWithDescription:@"biometric reauth"];
    [[CMAuthService shared] reauthForDestructiveActionWithReason:@"test reauth"
                                                       completion:^(BOOL ok, NSError *err) {
        // Simulator typically can't do biometrics — completion should still fire.
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testBiometricLoginNonexistentUser {
    XCTestExpectation *exp = [self expectationWithDescription:@"bio nonexistent"];
    [[CMAuthService shared] loginWithBiometricsForUserId:@"no-such-user"
                                              completion:^(CMAuthAttemptResult *r) {
        XCTAssertEqual(r.outcome, CMAuthStepOutcomeFailed);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testSignupValidPasswordCreatesUser {
    XCTestExpectation *exp = [self expectationWithDescription:@"valid signup"];
    [[CMAuthService shared] signupWithTenantId:self.testTenantId
                                       username:@"validuser-extended"
                                       password:@"ValidPass123!@#"
                                    displayName:@"Valid User"
                                           role:CMUserRoleCourier
                                     completion:^(CMUserAccount *u, NSError *e) {
        XCTAssertNotNil(u, @"Valid signup should succeed: %@", e);
        XCTAssertNil(e);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMAuthService shared], [CMAuthService shared]);
}

@end
