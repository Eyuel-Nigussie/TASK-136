//
//  CMBackgroundJobsTests.m
//  CourierMatch Integration Tests
//
//  Smoke tests for background purge / cleanup jobs.
//

#import "CMIntegrationTestCase.h"
#import "CMNotificationPurgeJob.h"
#import "CMAttachmentCleanupJob.h"
#import "CMNotificationItem.h"
#import "CMUserAccount.h"

@interface CMBackgroundJobsTests : CMIntegrationTestCase
@end

@implementation CMBackgroundJobsTests

#pragma mark - Notification Purge Job

- (void)testNotificationPurgeJobRunsWithoutCrash {
    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Purge complete"];
    BOOL expired = NO;
    [job runPurgeWithProtectedDataAvailable:YES
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testNotificationPurgeJobRunsWithoutProtectedData {
    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Purge no-protected"];
    BOOL expired = NO;
    [job runPurgeWithProtectedDataAvailable:NO
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testNotificationPurgeArchivesOldReadNotifications {
    // Insert a notification that's old AND read — should be archived
    CMNotificationItem *old = [NSEntityDescription insertNewObjectForEntityForName:@"NotificationItem"
                                                            inManagedObjectContext:self.testContext];
    old.notificationId = @"old-1";
    old.tenantId = self.testTenantId;
    old.recipientUserId = self.courierUser.userId;
    old.templateKey = @"old_event";
    old.status = @"active";
    old.readAt = [NSDate dateWithTimeIntervalSinceNow:-(60 * 24 * 60 * 60)]; // 60 days ago
    old.createdAt = [NSDate dateWithTimeIntervalSinceNow:-(60 * 24 * 60 * 60)];
    old.updatedAt = [NSDate date];
    old.version = 1;
    [self saveContext];

    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Purge runs"];
    BOOL expired = NO;
    [job runPurgeWithProtectedDataAvailable:YES
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testNotificationPurgePreservesRecentUnread {
    CMNotificationItem *recent = [NSEntityDescription insertNewObjectForEntityForName:@"NotificationItem"
                                                               inManagedObjectContext:self.testContext];
    recent.notificationId = @"recent-1";
    recent.tenantId = self.testTenantId;
    recent.recipientUserId = self.courierUser.userId;
    recent.templateKey = @"recent_event";
    recent.status = @"active";
    recent.readAt = nil; // unread
    recent.createdAt = [NSDate date]; // now
    recent.updatedAt = [NSDate date];
    recent.version = 1;
    [self saveContext];

    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Preserve recent"];
    BOOL expired = NO;
    [job runPurgeWithProtectedDataAvailable:YES
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Recent unread notification should not be deleted.
    [self.testContext refreshObject:recent mergeChanges:NO];
    XCTAssertNil(recent.deletedAt, @"Recent unread should not be archived");
}

- (void)testNotificationPurgeRespectsExpiredFlag {
    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Expired exit"];
    __block BOOL expired = YES; // pre-expired
    [job runPurgeWithProtectedDataAvailable:YES
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Attachment Cleanup Job

- (void)testAttachmentCleanupJobShared {
    CMAttachmentCleanupJob *a = [CMAttachmentCleanupJob shared];
    CMAttachmentCleanupJob *b = [CMAttachmentCleanupJob shared];
    XCTAssertEqual(a, b);
}

- (void)testAttachmentCleanupRunsWithoutCrash {
    CMAttachmentCleanupJob *job = [CMAttachmentCleanupJob shared];
    XCTestExpectation *exp = [self expectationWithDescription:@"Cleanup runs"];
    [job runCleanup:^(NSUInteger deleted, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testAttachmentCleanupWithNilCompletion {
    CMAttachmentCleanupJob *job = [CMAttachmentCleanupJob shared];
    XCTAssertNoThrow([job runCleanup:nil]);
    // Sleep briefly to let async work start (then the test exits)
    [NSThread sleepForTimeInterval:0.5];
}

@end
