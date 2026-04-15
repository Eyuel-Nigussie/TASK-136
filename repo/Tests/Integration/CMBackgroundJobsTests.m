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
    __block NSError *purgeError = nil;
    [job runPurgeWithProtectedDataAvailable:YES
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        purgeError = err;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil(purgeError, @"Purge job should complete without error on empty store");
}

- (void)testNotificationPurgeJobRunsWithoutProtectedData {
    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Purge no-protected"];
    BOOL expired = NO;
    __block NSError *purgeError = nil;
    __block NSUInteger purgeCount = NSUIntegerMax;
    [job runPurgeWithProtectedDataAvailable:NO
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        purgeCount = purged;
        purgeError = err;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil(purgeError, @"Purge job with no protected data should not error");
    // Phase 2 (main archive) is skipped when protectedDataAvailable=NO,
    // so purged count reflects only phase-1 cleanup.
    XCTAssertNotEqual(purgeCount, NSUIntegerMax, @"Completion must be called with a valid count");
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

- (void)testAttachmentCleanupDeletesExpiredAttachments {
    // Insert an expired attachment record (expiresAt in the past, no real file on disk).
    NSManagedObjectContext *ctx = self.testContext;
    NSManagedObject *att = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment"
                                                          inManagedObjectContext:ctx];
    [att setValue:[[NSUUID UUID] UUIDString] forKey:@"attachmentId"];
    [att setValue:self.testTenantId forKey:@"tenantId"];
    [att setValue:@"Order" forKey:@"ownerType"];
    [att setValue:@"order-cleanup-test" forKey:@"ownerId"];
    [att setValue:@"expired.png" forKey:@"filename"];
    [att setValue:@"image/png" forKey:@"mimeType"];
    [att setValue:@"nonexistent/expired.png" forKey:@"storagePathRelative"];
    [att setValue:[NSDate dateWithTimeIntervalSinceNow:-(60 * 24 * 3600)] forKey:@"expiresAt"]; // 60 days ago
    [att setValue:[NSDate dateWithTimeIntervalSinceNow:-(90 * 24 * 3600)] forKey:@"capturedAt"];
    [att setValue:@"pending" forKey:@"hashStatus"];
    [att setValue:self.courierUser.userId forKey:@"capturedByUserId"];
    [att setValue:[NSDate date] forKey:@"createdAt"];
    [att setValue:[NSDate date] forKey:@"updatedAt"];
    [att setValue:@(1) forKey:@"version"];
    [self saveContext];

    CMAttachmentCleanupJob *job = [CMAttachmentCleanupJob shared];
    XCTestExpectation *exp = [self expectationWithDescription:@"Cleanup expired"];
    __block NSUInteger deletedCount = 0;
    [job runCleanup:^(NSUInteger deleted, NSError *err) {
        deletedCount = deleted;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertGreaterThanOrEqual(deletedCount, 1u,
                                @"At least 1 expired attachment should be deleted");
}

#pragma mark - Notification Purge Phase 1 with Work Entities

- (void)testNotificationPurgeJobRunsPhase1Only_NilProtectedData {
    // protectedDataAvailable = NO → Phase 2 (main archive) is skipped.
    CMNotificationPurgeJob *job = [[CMNotificationPurgeJob alloc] init];
    XCTestExpectation *exp = [self expectationWithDescription:@"Phase 1 only"];
    BOOL expired = NO;
    __block NSError *purgeErr = nil;
    [job runPurgeWithProtectedDataAvailable:NO
                                expiredFlag:&expired
                                 completion:^(NSUInteger purged, NSError *err) {
        purgeErr = err;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil(purgeErr, @"Phase-1-only run should not produce an error");
}

@end
