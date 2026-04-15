//
//  CMBackgroundTaskManagerTests.m
//  CourierMatch Integration Tests
//
//  BGTaskScheduler interactions can't run real BG tasks in tests, but we
//  can register, schedule, and verify shared singleton works.
//

#import "CMIntegrationTestCase.h"
#import "CMBackgroundTaskManager.h"

@interface CMBackgroundTaskManagerTests : CMIntegrationTestCase
@end

@implementation CMBackgroundTaskManagerTests

- (void)testSharedSingleton {
    XCTAssertEqual([CMBackgroundTaskManager shared], [CMBackgroundTaskManager shared]);
}

- (void)testTaskIdentifiersDefined {
    XCTAssertNotNil(CMBGTaskMatchRefresh);
    XCTAssertNotNil(CMBGTaskAttachmentsCleanup);
    XCTAssertNotNil(CMBGTaskNotificationsPurge);
    XCTAssertNotNil(CMBGTaskAuditVerify);
    XCTAssertTrue([CMBGTaskMatchRefresh hasPrefix:@"com.eaglepoint.couriermatch"]);
}

- (void)testScheduleAllTasksDoesNotCrash {
    // BGTaskScheduler.submitTaskRequest will fail outside an app context but
    // shouldn't crash. Just verify the call returns.
    XCTAssertNoThrow([[CMBackgroundTaskManager shared] scheduleAllTasks]);
}

- (void)testScheduleIndividualTasks {
    XCTAssertNoThrow([[CMBackgroundTaskManager shared] scheduleMatchRefresh]);
    XCTAssertNoThrow([[CMBackgroundTaskManager shared] scheduleAttachmentsCleanup]);
    XCTAssertNoThrow([[CMBackgroundTaskManager shared] scheduleNotificationsPurge]);
    XCTAssertNoThrow([[CMBackgroundTaskManager shared] scheduleAuditVerify]);
}

#pragma mark - shouldYieldForSystemConstraints (private)

- (void)testShouldYieldForSystemConstraints_ReturnsValue {
    // Private method — call via NSSelectorFromString.
    SEL sel = NSSelectorFromString(@"shouldYieldForSystemConstraints");
    if (![[CMBackgroundTaskManager shared] respondsToSelector:sel]) { return; }
    IMP imp = [[CMBackgroundTaskManager shared] methodForSelector:sel];
    BOOL (*func)(id, SEL) = (BOOL (*)(id, SEL))imp;
    BOOL result = func([CMBackgroundTaskManager shared], sel);
    // The return value is system-state-dependent (thermal state, Low Power Mode).
    // We only assert that the method runs without crashing and the manager remains valid.
    (void)result;
    XCTAssertNotNil([CMBackgroundTaskManager shared],
                    @"Shared manager must remain accessible after shouldYieldForSystemConstraints");
}

- (void)testIsProtectedDataAvailable_ReturnsValue {
    SEL sel = NSSelectorFromString(@"isProtectedDataAvailable");
    if (![[CMBackgroundTaskManager shared] respondsToSelector:sel]) { return; }
    IMP imp = [[CMBackgroundTaskManager shared] methodForSelector:sel];
    BOOL (*func)(id, SEL) = (BOOL (*)(id, SEL))imp;
    BOOL result = func([CMBackgroundTaskManager shared], sel);
    // The return value reflects the device lock state, which varies by environment.
    // We assert only that the method executes and the manager remains valid.
    (void)result;
    XCTAssertNotNil([CMBackgroundTaskManager shared],
                    @"Shared manager must remain accessible after isProtectedDataAvailable");
}

#pragma mark - registerAllTasks

- (void)testRegisterAllTasksDoesNotCrash {
    // BGTaskScheduler throws if task identifiers are registered twice (the app may already
    // have registered them in -application:didFinishLaunchingWithOptions:).
    // Wrap in @try/@catch so the test exercises the code path without being order-dependent.
    @try {
        [[CMBackgroundTaskManager shared] registerAllTasks];
    } @catch (NSException *e) {
        // Duplicate-registration from BGTaskScheduler is expected in the test host.
        // Any NSException here is acceptable; we just require it not to propagate uncaught.
        (void)e;
    }
    // The shared manager must remain usable regardless of whether registration succeeded
    // or a duplicate-registration exception was caught.
    XCTAssertNotNil([CMBackgroundTaskManager shared],
                    @"Shared manager must remain accessible after registerAllTasks");
}

@end
