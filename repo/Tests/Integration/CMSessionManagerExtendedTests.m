//
//  CMSessionManagerExtendedTests.m
//  CourierMatch Integration Tests
//
//  Covers previously-uncovered CMSessionManager paths:
//  logout, recordActivity, evaluateSession, handleSceneDidEnterBackground,
//  handleSceneDidBecomeActive, preflightSensitiveAction
//

#import "CMIntegrationTestCase.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"

@interface CMSessionManagerExtendedTests : CMIntegrationTestCase
@end

@implementation CMSessionManagerExtendedTests

- (void)setUp {
    [super setUp];
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
}

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMSessionManager shared], [CMSessionManager shared]);
}

- (void)testLogout_ClearsSession {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertTrue([[CMSessionManager shared] hasActiveSession]);
    [[CMSessionManager shared] logout];
    XCTAssertFalse([[CMSessionManager shared] hasActiveSession],
                   @"Session must be inactive immediately after logout");
}

- (void)testRecordActivity_DoesNotCrash {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertNoThrow([[CMSessionManager shared] recordActivity]);
}

- (void)testHandleSceneDidBecomeActive_DoesNotCrash {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertNoThrow([[CMSessionManager shared] handleSceneDidBecomeActive]);
}

- (void)testHandleSceneDidEnterBackground_DoesNotCrash {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertNoThrow([[CMSessionManager shared] handleSceneDidEnterBackground]);
}

- (void)testHandleSceneDidBecomeActive_TriggerEvaluateSession {
    // handleSceneDidBecomeActive calls evaluateSession internally.
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    // Call multiple times to exercise the session evaluation path.
    XCTAssertNoThrow([[CMSessionManager shared] handleSceneDidBecomeActive]);
    XCTAssertNoThrow([[CMSessionManager shared] handleSceneDidBecomeActive]);
}

- (void)testPreflightSensitiveAction_WithValidSession {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    NSError *err = nil;
    // On simulator biometrics are unavailable, so preflight may succeed (no biometrics required)
    // or fail (biometric lock engaged). Either outcome is valid, but:
    //   - A failed preflight (NO) must always set an error.
    //   - A successful preflight (YES) must never set an error.
    BOOL result = [[CMSessionManager shared] preflightSensitiveActionWithError:&err];
    if (!result) {
        XCTAssertNotNil(err,
                        @"A failed preflight must set an error; returning NO with nil error is a bug");
    } else {
        XCTAssertNil(err,
                     @"A successful preflight must not set an error; returning YES with a non-nil error is a bug");
    }
}

- (void)testPreflightSensitiveAction_WithNoSession {
    [[CMSessionManager shared] logout];
    NSError *err = nil;
    BOOL result = [[CMSessionManager shared] preflightSensitiveActionWithError:&err];
    // No active session must always return NO with a non-nil error.
    XCTAssertFalse(result, @"Preflight with no active session must return NO");
    XCTAssertNotNil(err, @"Preflight with no active session must set a non-nil error");
}

- (void)testHandleSceneDidBecomeActive_AfterLogout {
    [[CMSessionManager shared] logout];
    // Should not crash even with no session.
    XCTAssertNoThrow([[CMSessionManager shared] handleSceneDidBecomeActive]);
}

- (void)testHasActiveSession_WhenOpen {
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    XCTAssertTrue([[CMSessionManager shared] hasActiveSession]);
}

@end
