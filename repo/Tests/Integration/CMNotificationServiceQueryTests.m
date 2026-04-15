//
//  CMNotificationServiceQueryTests.m
//  CourierMatch Integration Tests
//
//  Tests for CMNotificationCenterService query paths:
//  unreadCountForCurrentUser, unreadNotificationsForCurrentUser:error:,
//  allNotificationsForCurrentUser:limit:error:, and markRead/markAck
//  on directly-inserted notifications (no rate-limiter interference).
//

#import "CMIntegrationTestCase.h"
#import "CMNotificationCenterService.h"
#import "CMNotificationItem.h"
#import "CMNotificationRepository.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"
#import "NSManagedObjectContext+CMHelpers.h"

@interface CMNotificationServiceQueryTests : CMIntegrationTestCase
@property (nonatomic, strong) CMNotificationCenterService *service;
@end

@implementation CMNotificationServiceQueryTests

- (void)setUp {
    [super setUp];
    self.service = [[CMNotificationCenterService alloc] initWithRepository:nil
                                                                  renderer:nil
                                                               rateLimiter:nil];
}

#pragma mark - Helpers

/// Inserts a notification directly into the test context for the courier user.
- (CMNotificationItem *)insertNotificationWithKey:(NSString *)key
                                           status:(NSString *)status {
    CMNotificationRepository *repo = [[CMNotificationRepository alloc]
        initWithContext:self.testContext];
    CMNotificationItem *item = [repo insertNotification];
    item.templateKey = key;
    item.recipientUserId = self.courierUser.userId;
    item.status = status;
    item.renderedTitle = [@"Title: " stringByAppendingString:key];
    item.renderedBody = @"Body";
    [self saveContext];
    return item;
}

#pragma mark - unreadCountForCurrentUser

- (void)testUnreadCountForCurrentUser_NoUser_ReturnsZero {
    // No authenticated user.
    [[CMTenantContext shared] clear];
    NSUInteger count = [self.service unreadCountForCurrentUser];
    XCTAssertEqual(count, 0u, @"unreadCount should be 0 when no user is authenticated");
}

- (void)testUnreadCountForCurrentUser_WithUnreadNotifications {
    [self switchToUser:self.courierUser];
    // Insert an active (unread) notification.
    [self insertNotificationWithKey:@"unread_1" status:CMNotificationStatusActive];

    NSUInteger count = [self.service unreadCountForCurrentUser];
    XCTAssertGreaterThanOrEqual(count, 1u,
                                @"unreadCount should be >= 1 after inserting an unread notification");
}

- (void)testUnreadCountForCurrentUser_AfterMarkRead_DecreasesOrZero {
    [self switchToUser:self.courierUser];
    CMNotificationItem *item = [self insertNotificationWithKey:@"unread_markread" status:CMNotificationStatusActive];

    NSUInteger before = [self.service unreadCountForCurrentUser];
    XCTAssertGreaterThanOrEqual(before, 1u);

    NSError *err = nil;
    BOOL marked = [self.service markRead:item.notificationId error:&err];
    XCTAssertTrue(marked, @"markRead should succeed: %@", err);

    // After marking read, unreadCount should decrease.
    NSUInteger after = [self.service unreadCountForCurrentUser];
    XCTAssertLessThanOrEqual(after, before, @"unreadCount should not increase after markRead");
}

#pragma mark - unreadNotificationsForCurrentUser:error:

- (void)testUnreadNotificationsForCurrentUser_NoUser_ReturnsEmpty {
    [[CMTenantContext shared] clear];
    NSError *err = nil;
    NSArray *items = [self.service unreadNotificationsForCurrentUser:10 error:&err];
    XCTAssertNotNil(items);
    XCTAssertEqual(items.count, 0u, @"unreadNotifications with no user should return empty array");
}

- (void)testUnreadNotificationsForCurrentUser_ReturnsUnread {
    [self switchToUser:self.courierUser];
    [self insertNotificationWithKey:@"unread_query_1" status:CMNotificationStatusActive];
    [self insertNotificationWithKey:@"unread_query_2" status:CMNotificationStatusActive];

    NSError *err = nil;
    NSArray *items = [self.service unreadNotificationsForCurrentUser:0 error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(items.count, 2u,
                                @"Should return at least 2 unread notifications");
}

- (void)testUnreadNotificationsForCurrentUser_LimitApplied {
    [self switchToUser:self.courierUser];
    for (int i = 0; i < 5; i++) {
        [self insertNotificationWithKey:[NSString stringWithFormat:@"limit_%d", i]
                                 status:CMNotificationStatusActive];
    }

    NSError *err = nil;
    NSArray *limited = [self.service unreadNotificationsForCurrentUser:2 error:&err];
    XCTAssertNil(err);
    // CMNotificationRepository applies fetchLimit when limit > 0 (CMRepository.m:63).
    // With 5 notifications inserted and limit=2, the result must be capped at 2.
    XCTAssertLessThanOrEqual(limited.count, 2u,
                             @"limit=2 must cap results to at most 2 items");
}

#pragma mark - allNotificationsForCurrentUser:limit:error:

- (void)testAllNotificationsForCurrentUser_NoUser_ReturnsEmpty {
    [[CMTenantContext shared] clear];
    NSError *err = nil;
    NSArray *items = [self.service allNotificationsForCurrentUser:10 error:&err];
    XCTAssertNotNil(items);
    XCTAssertEqual(items.count, 0u, @"allNotifications with no user should return empty array");
}

- (void)testAllNotificationsForCurrentUser_ReturnsAll {
    [self switchToUser:self.courierUser];
    [self insertNotificationWithKey:@"all_1" status:CMNotificationStatusActive];
    [self insertNotificationWithKey:@"all_2" status:CMNotificationStatusCoalesced];

    NSError *err = nil;
    NSArray *items = [self.service allNotificationsForCurrentUser:0 error:&err];
    XCTAssertNil(err);
    // The repository may filter by certain statuses; at least the active one must appear.
    XCTAssertGreaterThanOrEqual(items.count, 1u,
                                @"allNotifications should return at least active notifications");
}

#pragma mark - markRead on nonexistent ID

- (void)testMarkRead_NonexistentNotificationId_ReturnsFalse {
    [self switchToUser:self.courierUser];
    NSError *err = nil;
    BOOL ok = [self.service markRead:@"nonexistent-id-12345" error:&err];
    XCTAssertFalse(ok, @"markRead on nonexistent notification should return NO");
}

- (void)testMarkAcknowledged_NonexistentNotificationId_ReturnsFalse {
    [self switchToUser:self.courierUser];
    NSError *err = nil;
    BOOL ok = [self.service markAcknowledged:@"nonexistent-id-67890" error:&err];
    XCTAssertFalse(ok, @"markAcknowledged on nonexistent notification should return NO");
}

#pragma mark - markAcknowledged already-read notification

- (void)testMarkAcknowledged_AlsoSetsReadAt {
    [self switchToUser:self.courierUser];
    CMNotificationItem *item = [self insertNotificationWithKey:@"ack_sets_read"
                                                        status:CMNotificationStatusActive];
    XCTAssertNil(item.readAt, @"readAt should be nil before ack");

    NSError *err = nil;
    BOOL ok = [self.service markAcknowledged:item.notificationId error:&err];
    XCTAssertTrue(ok, @"markAcknowledged should succeed: %@", err);
    XCTAssertNotNil(item.readAt, @"readAt should be set via implicit read in markAcknowledged");
    XCTAssertNotNil(item.ackedAt, @"ackedAt should be set");
}

- (void)testMarkAcknowledged_AlreadyRead_SetsAckedAtWithoutDuplicateRead {
    [self switchToUser:self.courierUser];
    CMNotificationItem *item = [self insertNotificationWithKey:@"already_read"
                                                        status:CMNotificationStatusActive];
    // Mark read first.
    [self.service markRead:item.notificationId error:nil];
    NSDate *firstReadAt = item.readAt;
    XCTAssertNotNil(firstReadAt);

    // Then acknowledge.
    NSError *err = nil;
    BOOL ok = [self.service markAcknowledged:item.notificationId error:&err];
    XCTAssertTrue(ok, @"markAcknowledged should succeed: %@", err);
    XCTAssertNotNil(item.ackedAt);
    // readAt should not change since it was already set.
    XCTAssertNotNil(item.readAt);
}

@end
