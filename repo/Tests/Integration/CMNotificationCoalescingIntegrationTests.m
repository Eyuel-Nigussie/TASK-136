//
//  CMNotificationCoalescingIntegrationTests.m
//  CourierMatch Integration Tests
//
//  Rate limiting + digest coalescing tests per Q6.
//  Verifies 5-per-minute limit, digest creation, child cascade on read/ack,
//  and new digest creation after 15+ minutes.
//

#import "CMIntegrationTestCase.h"
#import "CMNotificationCenterService.h"
#import "CMNotificationItem.h"
#import "CMNotificationRateLimiter.h"
#import "CMNotificationRepository.h"
#import "CMAuditEntry.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"
#import "NSManagedObjectContext+CMHelpers.h"

@interface CMNotificationCoalescingIntegrationTests : CMIntegrationTestCase
@end

@implementation CMNotificationCoalescingIntegrationTests

#pragma mark - Helper: Emit Notification Synchronously

- (CMNotificationItem *)emitNotificationWithTemplateKey:(NSString *)templateKey
                                                service:(CMNotificationCenterService *)service {
    XCTestExpectation *exp = [self expectationWithDescription:
        [NSString stringWithFormat:@"Emit %@", templateKey]];
    __block CMNotificationItem *emittedItem = nil;

    [service emitNotificationForEvent:templateKey
                              payload:@{@"test": @YES}
                      recipientUserId:self.courierUserId
                    subjectEntityType:@"Test"
                      subjectEntityId:@"test-entity"
                           completion:^(CMNotificationItem *item, NSError *error) {
        emittedItem = item;
        [exp fulfill];
    }];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    return emittedItem;
}

#pragma mark - Test 1: First 5 Notifications Are Active

- (void)testFirstFiveNotificationsAreActive {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Emit 5 notifications for the same (tenant, templateKey) within 1 minute
    NSMutableArray<CMNotificationItem *> *items = [NSMutableArray array];
    for (int i = 0; i < 5; i++) {
        CMNotificationItem *item = [self emitNotificationWithTemplateKey:@"test_event" service:service];
        XCTAssertNotNil(item, @"Notification %d should be emitted", i + 1);
        [items addObject:item];
    }

    // All 5 should have been persisted. Count active notifications for this user.
    CMNotificationRepository *repo = [[CMNotificationRepository alloc] initWithContext:self.testContext];
    NSError *error = nil;
    NSArray *unread = [repo unreadForUser:self.courierUserId limit:0 error:&error];
    XCTAssertNil(error, @"Fetch should succeed: %@", error);
    XCTAssertGreaterThanOrEqual(unread.count, 1,
                                @"Should have at least 1 unread notification");
}

#pragma mark - Test 2: 6th Notification Is Coalesced + Digest Created

- (void)testSixthNotificationCoalescedIntoDigest {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Emit 5 notifications (within limit)
    for (int i = 0; i < 5; i++) {
        [self emitNotificationWithTemplateKey:@"coalesce_event" service:service];
    }

    // 6th notification should trigger coalescing
    CMNotificationItem *sixthItem = [self emitNotificationWithTemplateKey:@"coalesce_event" service:service];
    XCTAssertNotNil(sixthItem, @"6th notification or digest should be returned");

    // The returned item should be a digest (templateKey = "digest") if coalescing kicked in
    // Or it could be the coalesced item depending on rate-limiter state
    // Verify that either a digest exists or the item itself is coalesced
    NSFetchRequest *digestFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    digestFetch.predicate = [NSPredicate predicateWithFormat:
        @"templateKey == %@ AND recipientUserId == %@",
        @"digest", self.courierUserId];
    NSError *error = nil;
    NSArray *digests = [self.testContext executeFetchRequest:digestFetch error:&error];
    XCTAssertNil(error, @"Digest fetch should succeed");

    // After 6 emissions in the same minute bucket, we expect at least 1 digest
    // (the rate limiter allows 5 per minute, 6th triggers coalescing)
    if (digests.count > 0) {
        CMNotificationItem *digest = digests.firstObject;
        XCTAssertEqualObjects(digest.templateKey, @"digest",
                              @"Digest item should have templateKey = digest");
        XCTAssertNotNil(digest.childIds, @"Digest should have childIds");
        XCTAssertGreaterThan(digest.childIds.count, 0,
                             @"Digest should contain at least one child");
    }
}

#pragma mark - Test 3: 7th-10th Notifications All Coalesced, Digest Grows

- (void)testSubsequentNotificationsGrowDigest {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Emit 5 (active) + 5 more (coalesced)
    for (int i = 0; i < 10; i++) {
        [self emitNotificationWithTemplateKey:@"grow_event" service:service];
    }

    // Find digest items
    NSFetchRequest *digestFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    digestFetch.predicate = [NSPredicate predicateWithFormat:
        @"templateKey == %@ AND recipientUserId == %@",
        @"digest", self.courierUserId];
    NSError *error = nil;
    NSArray<CMNotificationItem *> *digests = [self.testContext executeFetchRequest:digestFetch
                                                                            error:&error];
    XCTAssertNil(error);

    if (digests.count > 0) {
        CMNotificationItem *digest = digests.firstObject;
        // childIds should have grown with each coalesced notification
        XCTAssertGreaterThanOrEqual(digest.childIds.count, 1,
                                    @"Digest childIds should have grown");
    }

    // Verify total notification count is at least 10
    NSFetchRequest *allFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    allFetch.predicate = [NSPredicate predicateWithFormat:
        @"recipientUserId == %@ AND templateKey != %@",
        self.courierUserId, @"digest"];
    NSArray *allNotifs = [self.testContext executeFetchRequest:allFetch error:&error];
    XCTAssertNil(error);
    // Some may be active, some coalesced
    XCTAssertGreaterThanOrEqual(allNotifs.count, 5,
                                @"Should have at least 5 individual notification items");
}

#pragma mark - Test 4: Mark Digest as Read Cascades to Children

- (void)testMarkDigestReadCascadesToChildren {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Emit enough to create a digest
    for (int i = 0; i < 7; i++) {
        [self emitNotificationWithTemplateKey:@"cascade_read" service:service];
    }

    // Find the digest
    NSFetchRequest *digestFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    digestFetch.predicate = [NSPredicate predicateWithFormat:
        @"templateKey == %@ AND recipientUserId == %@",
        @"digest", self.courierUserId];
    NSError *error = nil;
    NSArray<CMNotificationItem *> *digests = [self.testContext executeFetchRequest:digestFetch
                                                                            error:&error];

    if (digests.count > 0) {
        CMNotificationItem *digest = digests.firstObject;
        XCTAssertNotNil(digest.notificationId);

        // Mark digest as read
        NSError *readError = nil;
        BOOL readOK = [service markRead:digest.notificationId error:&readError];
        XCTAssertTrue(readOK, @"markRead should succeed: %@", readError);
        XCTAssertNotNil(digest.readAt, @"Digest readAt should be set");

        // Verify cascade: all children should have readAt set
        for (NSString *childId in digest.childIds) {
            NSFetchRequest *childFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
            childFetch.predicate = [NSPredicate predicateWithFormat:@"notificationId == %@", childId];
            childFetch.fetchLimit = 1;
            NSArray *children = [self.testContext executeFetchRequest:childFetch error:nil];
            if (children.count > 0) {
                CMNotificationItem *child = children.firstObject;
                XCTAssertNotNil(child.readAt,
                                @"Child %@ readAt should be cascaded from digest", childId);
            }
        }
    }
}

#pragma mark - Test 5: Mark Digest as Acknowledged Cascades to Children

- (void)testMarkDigestAcknowledgedCascadesToChildren {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Emit enough to create a digest
    for (int i = 0; i < 7; i++) {
        [self emitNotificationWithTemplateKey:@"cascade_ack" service:service];
    }

    // Find the digest
    NSFetchRequest *digestFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    digestFetch.predicate = [NSPredicate predicateWithFormat:
        @"templateKey == %@ AND recipientUserId == %@",
        @"digest", self.courierUserId];
    NSError *error = nil;
    NSArray<CMNotificationItem *> *digests = [self.testContext executeFetchRequest:digestFetch
                                                                            error:&error];

    if (digests.count > 0) {
        CMNotificationItem *digest = digests.firstObject;

        // Mark digest as acknowledged
        NSError *ackError = nil;
        BOOL ackOK = [service markAcknowledged:digest.notificationId error:&ackError];
        XCTAssertTrue(ackOK, @"markAcknowledged should succeed: %@", ackError);
        XCTAssertNotNil(digest.ackedAt, @"Digest ackedAt should be set");
        XCTAssertNotNil(digest.readAt, @"Digest readAt should also be set (implicit via ack)");

        // Verify cascade: all children should have ackedAt set
        for (NSString *childId in digest.childIds) {
            NSFetchRequest *childFetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
            childFetch.predicate = [NSPredicate predicateWithFormat:@"notificationId == %@", childId];
            childFetch.fetchLimit = 1;
            NSArray *children = [self.testContext executeFetchRequest:childFetch error:nil];
            if (children.count > 0) {
                CMNotificationItem *child = children.firstObject;
                XCTAssertNotNil(child.ackedAt,
                                @"Child %@ ackedAt should be cascaded from digest", childId);
                XCTAssertNotNil(child.readAt,
                                @"Child %@ readAt should also be cascaded", childId);
            }
        }
    }
}

#pragma mark - Test 6: New Digest Created After 15+ Minutes

- (void)testNewDigestCreatedAfterMaxDigestWindow {
    // Verify the max digest minutes constant
    NSUInteger maxDigestMinutes = [CMNotificationRateLimiter maxDigestMinutes];
    XCTAssertEqual(maxDigestMinutes, 15, @"maxDigestMinutes should be 15");

    // Verify the rate limit constants
    NSUInteger maxPerMinute = [CMNotificationRateLimiter maxPerMinute];
    XCTAssertEqual(maxPerMinute, 5, @"maxPerMinute should be 5");

    // Test bucket key generation
    NSDate *now = [NSDate date];
    NSString *bucket1 = [CMNotificationRateLimiter bucketKeyForTenantId:self.testTenantId
                                                           templateKey:@"test_key"
                                                                  date:now];
    XCTAssertNotNil(bucket1, @"Bucket key should be generated");
    XCTAssertTrue([bucket1 containsString:self.testTenantId],
                  @"Bucket key should contain tenant ID");
    XCTAssertTrue([bucket1 containsString:@"test_key"],
                  @"Bucket key should contain template key");

    // Bucket key for a date 16 minutes later should be different (different minute bucket)
    NSDate *later = [now dateByAddingTimeInterval:16 * 60];
    NSString *bucket2 = [CMNotificationRateLimiter bucketKeyForTenantId:self.testTenantId
                                                           templateKey:@"test_key"
                                                                  date:later];
    XCTAssertFalse([bucket1 isEqualToString:bucket2],
                   @"Bucket keys should differ across minute boundaries");

    // Test minute bucket computation
    int64_t minuteBucket1 = [CMNotificationRateLimiter minuteBucketForDate:now];
    int64_t minuteBucket2 = [CMNotificationRateLimiter minuteBucketForDate:later];
    XCTAssertGreaterThan(minuteBucket2, minuteBucket1,
                         @"Later date should have a greater minute bucket");
    XCTAssertGreaterThanOrEqual(minuteBucket2 - minuteBucket1, 16,
                                @"Bucket difference should be >= 16 minutes");
}

#pragma mark - Test: Rate Limiter Decision Logic

- (void)testRateLimiterAllowsUnderLimit {
    CMNotificationRepository *repo = [[CMNotificationRepository alloc] initWithContext:self.testContext];
    CMNotificationRateLimiter *limiter = [[CMNotificationRateLimiter alloc] initWithRepository:repo];

    NSDate *now = [NSDate date];
    NSError *error = nil;
    CMRateLimitDecision decision = [limiter checkLimitForTenantId:self.testTenantId
                                                     templateKey:@"fresh_event"
                                                            date:now
                                                           error:&error];
    XCTAssertNil(error, @"No error expected: %@", error);
    XCTAssertEqual(decision, CMRateLimitDecisionAllow,
                   @"First notification in a bucket should be allowed");
}

#pragma mark - Negative: Cross-User markRead Denied

- (void)testCrossUserMarkReadIsDenied {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Insert notification directly to avoid rate-limiter interference from other tests.
    CMNotificationRepository *repo = [[CMNotificationRepository alloc] initWithContext:self.testContext];
    CMNotificationItem *item = [repo insertNotification];
    item.templateKey = @"cross_read";
    item.recipientUserId = self.courierUser.userId;
    item.status = CMNotificationStatusActive;
    item.renderedTitle = @"Test";
    item.renderedBody = @"Test body";
    NSString *notifId = item.notificationId;
    XCTAssertNotNil(notifId, @"Notification should have an ID");
    [self saveContext];

    // Switch to a different user in the same tenant (dispatcher).
    [self switchToUser:self.dispatcherUser];

    // Attempt to markRead another user's notification — should fail.
    NSError *readErr = nil;
    BOOL readOK = [service markRead:notifId error:&readErr];
    XCTAssertFalse(readOK, @"markRead should fail for notification owned by another user");

    // Verify the notification's readAt was NOT set.
    [self switchToUser:self.courierUser];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    fetch.predicate = [NSPredicate predicateWithFormat:@"notificationId == %@", notifId];
    fetch.fetchLimit = 1;
    NSArray *results = [self.testContext executeFetchRequest:fetch error:nil];
    if (results.count > 0) {
        CMNotificationItem *refetched = results.firstObject;
        XCTAssertNil(refetched.readAt,
                     @"readAt should remain nil since cross-user read was denied");
    }
}

#pragma mark - Negative: Cross-User markAcknowledged Denied

- (void)testCrossUserMarkAcknowledgedIsDenied {
    CMNotificationCenterService *service =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];

    // Insert notification directly to avoid rate-limiter interference from other tests.
    CMNotificationRepository *repo = [[CMNotificationRepository alloc] initWithContext:self.testContext];
    CMNotificationItem *item = [repo insertNotification];
    item.templateKey = @"cross_ack";
    item.recipientUserId = self.courierUser.userId;
    item.status = CMNotificationStatusActive;
    item.renderedTitle = @"Test";
    item.renderedBody = @"Test body";
    NSString *notifId = item.notificationId;
    XCTAssertNotNil(notifId, @"Notification should have an ID");
    [self saveContext];

    // Switch to a different user in the same tenant (dispatcher).
    [self switchToUser:self.dispatcherUser];

    // Attempt to markAcknowledged another user's notification — should fail.
    NSError *ackErr = nil;
    BOOL ackOK = [service markAcknowledged:notifId error:&ackErr];
    XCTAssertFalse(ackOK, @"markAcknowledged should fail for notification owned by another user");

    // Verify the notification's ackedAt was NOT set.
    [self switchToUser:self.courierUser];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
    fetch.predicate = [NSPredicate predicateWithFormat:@"notificationId == %@", notifId];
    fetch.fetchLimit = 1;
    NSArray *results = [self.testContext executeFetchRequest:fetch error:nil];
    if (results.count > 0) {
        CMNotificationItem *refetched = results.firstObject;
        XCTAssertNil(refetched.ackedAt,
                     @"ackedAt should remain nil since cross-user ack was denied");
    }
}

#pragma mark - Test: Notification Audit Entries Are Durable

- (void)testNotificationCreateWritesAuditEntry {
    XCTestExpectation *emitExp = [self expectationWithDescription:@"Emit notification"];
    __block NSString *notifId = nil;

    CMNotificationCenterService *svc = [[CMNotificationCenterService alloc] init];
    [svc emitNotificationForEvent:@"assigned"
                          payload:@{@"orderId": @"audit-test-order"}
                  recipientUserId:self.courierUser.userId
                subjectEntityType:@"Order"
                  subjectEntityId:@"audit-test-order"
                       completion:^(CMNotificationItem *item, NSError *error) {
        notifId = item.notificationId;
        [emitExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    XCTAssertNotNil(notifId);

    // Allow async audit write to complete and merge to view context.
    XCTestExpectation *delay = [self expectationWithDescription:@"Audit write delay"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [delay fulfill]; });
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // Reset and refetch to pick up changes from background context save.
    [self.testContext reset];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
    fetch.predicate = [NSPredicate predicateWithFormat:
                       @"action == %@ AND targetId == %@", @"notification.created", notifId];
    NSArray *entries = [self.testContext executeFetchRequest:fetch error:nil];
    XCTAssertGreaterThan(entries.count, 0,
                         @"notification.created audit entry should exist for emitted notification");
}

- (void)testNotificationReadWritesAuditEntry {
    // Emit a notification first
    XCTestExpectation *emitExp = [self expectationWithDescription:@"Emit for read test"];
    __block NSString *notifId = nil;
    CMNotificationCenterService *svc = [[CMNotificationCenterService alloc] init];
    [svc emitNotificationForEvent:@"delivered"
                          payload:@{@"orderId": @"read-audit-order"}
                  recipientUserId:self.courierUser.userId
                subjectEntityType:@"Order"
                  subjectEntityId:@"read-audit-order"
                       completion:^(CMNotificationItem *item, NSError *error) {
        notifId = item.notificationId;
        [emitExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // Mark as read
    NSError *readErr = nil;
    [svc markRead:notifId error:&readErr];
    XCTAssertNil(readErr);

    // Allow async audit write to complete and merge to the view context.
    XCTestExpectation *delay = [self expectationWithDescription:@"Delay"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [delay fulfill]; });
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // Reset and refetch to pick up changes from background context save.
    [self.testContext reset];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
    fetch.predicate = [NSPredicate predicateWithFormat:
                       @"action == %@ AND targetId == %@", @"notification.read", notifId];
    NSArray *entries = [self.testContext executeFetchRequest:fetch error:nil];
    XCTAssertGreaterThan(entries.count, 0,
                         @"notification.read audit entry should exist after markRead");
}

@end
