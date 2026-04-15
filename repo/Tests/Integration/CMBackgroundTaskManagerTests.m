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

@end
