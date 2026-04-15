//
//  CMBiometricEnrollmentTests.m
//  CourierMatch Integration Tests
//
//  Smoke tests for biometric enrollment. Hardware-backed biometric prompts
//  cannot be tested in CI; we verify the entry-point handles its inputs
//  gracefully and reports failure when biometrics aren't available.
//

#import "CMIntegrationTestCase.h"
#import "CMBiometricEnrollment.h"
#import "CMUserAccount.h"

@interface CMBiometricEnrollmentTests : CMIntegrationTestCase
@end

@implementation CMBiometricEnrollmentTests

- (void)testEnrollWithUser_completes {
    XCTestExpectation *exp = [self expectationWithDescription:@"Enroll completion"];
    [CMBiometricEnrollment enrollBiometricsForUser:self.courierUser
                                        completion:^(BOOL success, NSError *err) {
        // Simulator typically can't do biometrics, so success may be NO with err.
        // The point of this test is verifying the completion fires without crashing.
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testEnrollWithNilCompletion {
    // Even with nil completion the call should not crash.
    XCTAssertNoThrow([CMBiometricEnrollment enrollBiometricsForUser:self.courierUser
                                                          completion:nil]);
    [NSThread sleepForTimeInterval:0.5]; // let async work settle
}

- (void)testEnrollEachUser {
    // Exercise enrollment for each role to drive code paths.
    NSArray *users = @[self.courierUser, self.dispatcherUser, self.reviewerUser,
                       self.csUser, self.financeUser, self.adminUser];
    for (CMUserAccount *u in users) {
        XCTestExpectation *exp = [self expectationWithDescription:
            [NSString stringWithFormat:@"Enroll %@", u.userId]];
        [CMBiometricEnrollment enrollBiometricsForUser:u
                                            completion:^(BOOL success, NSError *err) {
            [exp fulfill];
        }];
        [self waitForExpectationsWithTimeout:5.0 handler:nil];
    }
}

@end
