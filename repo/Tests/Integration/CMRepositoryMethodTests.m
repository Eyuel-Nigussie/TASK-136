//
//  CMRepositoryMethodTests.m
//  CourierMatch Integration Tests
//
//  Covers previously-uncovered repository methods across multiple repositories.
//

#import "CMIntegrationTestCase.h"
#import "CMAppealRepository.h"
#import "CMScorecardRepository.h"
#import "CMItineraryRepository.h"
#import "CMRubricRepository.h"
#import "CMTenantRepository.h"
#import "CMDisputeRepository.h"
#import "CMOrderRepository.h"
#import "CMMatchCandidateRepository.h"
#import "CMAuditRepository.h"
#import "CMLoginHistoryRepository.h"
#import "CMNotificationRepository.h"
#import "CMAttachmentRepository.h"
#import "CMUserRepository.h"
#import "CMAppeal.h"
#import "CMDeliveryScorecard.h"
#import "CMItinerary.h"
#import "CMRubricTemplate.h"
#import "CMTenant.h"
#import "CMDispute.h"
#import "CMOrder.h"
#import "CMMatchCandidate.h"
#import "CMAttachment.h"
#import "CMUserAccount.h"
#import "CMWorkEntities.h"

@interface CMRepositoryMethodTests : CMIntegrationTestCase
@end

@implementation CMRepositoryMethodTests

// ── Appeal Repository ──────────────────────────────────────────────────────

- (void)testAppealRepository_FindById {
    [self switchToUser:self.reviewerUser];
    CMAppealRepository *repo = [[CMAppealRepository alloc] initWithContext:self.testContext];
    CMAppeal *a = [repo insertAppeal];
    a.scorecardId = @"sc-repo-1";
    a.reason = @"test";
    a.openedBy = self.reviewerUser.userId;
    a.openedAt = [NSDate date];
    [self saveContext];

    NSError *err = nil;
    CMAppeal *found = [repo findById:a.appealId error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
    XCTAssertEqualObjects(found.appealId, a.appealId);
}

- (void)testAppealRepository_AppealsForScorecard {
    [self switchToUser:self.reviewerUser];
    CMAppealRepository *repo = [[CMAppealRepository alloc] initWithContext:self.testContext];

    CMAppeal *a1 = [repo insertAppeal];
    a1.scorecardId = @"sc-repo-shared";
    a1.reason = @"r1";
    a1.openedBy = self.reviewerUser.userId;
    a1.openedAt = [NSDate date];

    CMAppeal *a2 = [repo insertAppeal];
    a2.scorecardId = @"sc-repo-shared";
    a2.reason = @"r2";
    a2.openedBy = self.reviewerUser.userId;
    a2.openedAt = [NSDate dateWithTimeIntervalSinceNow:-10];
    [self saveContext];

    NSError *err = nil;
    NSArray *appeals = [repo appealsForScorecard:@"sc-repo-shared" error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(appeals.count, 2);
}

- (void)testAppealRepository_PendingAppeals {
    [self switchToUser:self.reviewerUser];
    CMAppealRepository *repo = [[CMAppealRepository alloc] initWithContext:self.testContext];

    CMAppeal *a = [repo insertAppeal];
    a.scorecardId = @"sc-pending-1";
    a.reason = @"pending";
    a.openedBy = self.reviewerUser.userId;
    a.openedAt = [NSDate date];
    // decision = nil → pending
    [self saveContext];

    NSError *err = nil;
    NSArray *pending = [repo pendingAppeals:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(pending.count, 1);
}

// ── Scorecard Repository ───────────────────────────────────────────────────

- (void)testScorecardRepository_FindById {
    [self switchToUser:self.reviewerUser];
    CMScorecardRepository *repo = [[CMScorecardRepository alloc] initWithContext:self.testContext];
    [self insertTestRubric:@"r-sc-repo"];
    CMOrder *o = [self insertTestOrder:@"ord-sc-repo"];
    o.status = CMOrderStatusDelivered;
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDeliveryScorecard *sc = [repo insertScorecard];
    sc.orderId = o.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"r-sc-repo";
    sc.rubricVersion = 1;
    [self saveContext];

    NSError *err = nil;
    CMDeliveryScorecard *found = [repo findById:sc.scorecardId error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
}

- (void)testScorecardRepository_FindForOrder {
    [self switchToUser:self.reviewerUser];
    CMScorecardRepository *repo = [[CMScorecardRepository alloc] initWithContext:self.testContext];
    [self insertTestRubric:@"r-sc-order"];
    CMOrder *o = [self insertTestOrder:@"ord-sc-forder"];
    o.status = CMOrderStatusDelivered;
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDeliveryScorecard *sc = [repo insertScorecard];
    sc.orderId = o.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"r-sc-order";
    sc.rubricVersion = 1;
    [self saveContext];

    NSError *err = nil;
    CMDeliveryScorecard *found = [repo findForOrder:o.orderId error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
    XCTAssertEqualObjects(found.orderId, o.orderId);
}

// ── Itinerary Repository ───────────────────────────────────────────────────

- (void)testItineraryRepository_ActiveItineraries {
    [self switchToUser:self.dispatcherUser];
    CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:self.testContext];
    CMItinerary *it = [repo insertItinerary];
    it.courierId = self.courierUser.userId;
    it.status = CMItineraryStatusActive;
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    NSError *err = nil;
    NSArray *actives = [repo activeItineraries:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(actives.count, 1);
}

- (void)testItineraryRepository_ActiveForCourierId {
    [self switchToUser:self.dispatcherUser];
    CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:self.testContext];
    CMItinerary *it = [repo insertItinerary];
    it.courierId = self.courierUser.userId;
    it.status = CMItineraryStatusActive;
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    NSError *err = nil;
    NSArray *items = [repo activeForCourierId:self.courierUser.userId error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(items.count, 1);
}

- (void)testItineraryRepository_AllActiveForBackground {
    [self switchToUser:self.dispatcherUser];
    CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:self.testContext];
    CMItinerary *it = [repo insertItinerary];
    it.courierId = self.courierUser.userId;
    it.status = CMItineraryStatusActive;
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    NSError *err = nil;
    NSArray *items = [repo allActiveItinerariesForBackground:&err];
    XCTAssertNil(err);
    XCTAssertNotNil(items);
}

- (void)testItineraryRepository_FindById {
    [self switchToUser:self.dispatcherUser];
    CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:self.testContext];
    CMItinerary *it = [repo insertItinerary];
    it.courierId = self.courierUser.userId;
    it.status = CMItineraryStatusActive;
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    NSError *err = nil;
    CMItinerary *found = [repo findById:it.itineraryId error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
}

// ── Rubric Repository ──────────────────────────────────────────────────────

- (void)testRubricRepository_ActiveRubricForTenant {
    [self switchToUser:self.adminUser];
    [self insertTestRubric:@"r-active-repo"];
    CMRubricRepository *repo = [[CMRubricRepository alloc] initWithContext:self.testContext];

    NSError *err = nil;
    CMRubricTemplate *active = [repo activeRubricForTenant:&err];
    XCTAssertNil(err);
    // May or may not find a rubric depending on which is active.
    (void)active;
}

- (void)testRubricRepository_FindByIdAndVersion {
    [self switchToUser:self.adminUser];
    CMRubricTemplate *r = [self insertTestRubric:@"r-ver-repo"];
    r.rubricVersion = 3;
    [self saveContext];

    CMRubricRepository *repo = [[CMRubricRepository alloc] initWithContext:self.testContext];
    NSError *err = nil;
    CMRubricTemplate *found = [repo findById:@"r-ver-repo" rubricVersion:3 error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
}

// ── Tenant Repository ──────────────────────────────────────────────────────

- (void)testTenantRepository_AllActive {
    [self switchToUser:self.adminUser];
    CMTenantRepository *repo = [[CMTenantRepository alloc] initWithContext:self.testContext];
    NSError *err = nil;
    NSArray *tenants = [repo allActive:&err];
    XCTAssertNil(err);
    // The test tenant is active.
    XCTAssertGreaterThanOrEqual(tenants.count, 1);
}

- (void)testTenantRepository_AllActiveForBackground {
    CMTenantRepository *repo = [[CMTenantRepository alloc] initWithContext:self.testContext];
    NSError *err = nil;
    NSArray *tenants = [repo allActiveForBackground:&err];
    XCTAssertNil(err);
    XCTAssertNotNil(tenants);
}

- (void)testTenantRepository_InsertTenant {
    [self switchToUser:self.adminUser];
    CMTenantRepository *repo = [[CMTenantRepository alloc] initWithContext:self.testContext];
    CMTenant *t = [repo insertTenant];
    XCTAssertNotNil(t);
    XCTAssertNotNil(t.tenantId);
}

// ── Dispute Repository ─────────────────────────────────────────────────────

- (void)testDisputeRepository_OpenDisputes {
    [self switchToUser:self.csUser];
    CMOrder *o = [self insertTestOrder:@"ord-disp-open"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDisputeRepository *repo = [[CMDisputeRepository alloc] initWithContext:self.testContext];
    CMDispute *d = [repo insertDispute];
    d.orderId = o.orderId;
    d.openedBy = self.csUser.userId;
    d.reason = @"open dispute";
    d.openedAt = [NSDate date];
    // resolvedAt = nil → open
    [self saveContext];

    NSError *err = nil;
    NSArray *open = [repo openDisputes:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(open.count, 1);
}

- (void)testDisputeRepository_DisputesForOrder {
    [self switchToUser:self.csUser];
    CMOrder *o = [self insertTestOrder:@"ord-disp-for-order"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDisputeRepository *repo = [[CMDisputeRepository alloc] initWithContext:self.testContext];
    CMDispute *d = [repo insertDispute];
    d.orderId = o.orderId;
    d.openedBy = self.csUser.userId;
    d.reason = @"for-order dispute";
    d.openedAt = [NSDate date];
    [self saveContext];

    NSError *err = nil;
    NSArray *disputes = [repo disputesForOrder:o.orderId error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(disputes.count, 1);
}

// ── LoginHistory Repository ────────────────────────────────────────────────

- (void)testLoginHistoryRepository_RecentForUser {
    [self switchToUser:self.courierUser];
    CMLoginHistoryRepository *repo = [[CMLoginHistoryRepository alloc] initWithContext:self.testContext];
    [repo recordEntryForUserId:self.courierUser.userId
                      tenantId:self.testTenantId
                       outcome:@"success"];
    [self saveContext];

    NSError *err = nil;
    NSArray *history = [repo recentForUserId:self.courierUser.userId limit:10 error:&err];
    XCTAssertNil(err);
    XCTAssertNotNil(history);
}

// ── Order Repository ───────────────────────────────────────────────────────

- (void)testOrderRepository_FindById {
    [self switchToUser:self.dispatcherUser];
    CMOrderRepository *repo = [[CMOrderRepository alloc] initWithContext:self.testContext];
    CMOrder *o = [self insertTestOrder:@"ord-repo-find"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    NSError *err = nil;
    CMOrder *found = [repo findByOrderId:@"ord-repo-find" error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
}

- (void)testOrderRepository_OrdersWithStatus {
    [self switchToUser:self.dispatcherUser];
    CMOrderRepository *repo = [[CMOrderRepository alloc] initWithContext:self.testContext];
    CMOrder *o = [self insertTestOrder:@"ord-repo-status"];
    o.status = CMOrderStatusNew;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    o.pickupWindowStart = [NSDate date];
    o.pickupWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    NSError *err = nil;
    NSArray *items = [repo ordersWithStatus:CMOrderStatusNew limit:0 error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(items.count, 1);
}

// ── Attachment Repository ──────────────────────────────────────────────────

- (void)testAttachmentRepository_FindById {
    [self switchToUser:self.courierUser];
    CMAttachmentRepository *repo = [[CMAttachmentRepository alloc] initWithContext:self.testContext];
    CMAttachment *att = (CMAttachment *)[NSEntityDescription insertNewObjectForEntityForName:@"Attachment"
                                                                       inManagedObjectContext:self.testContext];
    att.attachmentId = [[NSUUID UUID] UUIDString];
    att.tenantId = self.testTenantId;
    att.ownerType = @"Order";
    att.ownerId = @"ord-att-repo";
    att.filename = @"test.png";
    att.mimeType = @"image/png";
    att.storagePathRelative = @"test/path.png";
    att.capturedAt = [NSDate date];
    att.expiresAt = [NSDate dateWithTimeIntervalSinceNow:86400];
    att.hashStatus = CMAttachmentHashStatusPending;
    att.capturedByUserId = self.courierUser.userId;
    att.createdAt = [NSDate date];
    att.updatedAt = [NSDate date];
    att.version = 1;
    [self saveContext];

    NSError *err = nil;
    CMAttachment *found = [repo findById:att.attachmentId error:&err];
    XCTAssertNotNil(found);
    XCTAssertNil(err);
}

- (void)testAttachmentRepository_AttachmentsForOwner {
    [self switchToUser:self.courierUser];
    CMAttachmentRepository *repo = [[CMAttachmentRepository alloc] initWithContext:self.testContext];
    CMAttachment *att = (CMAttachment *)[NSEntityDescription insertNewObjectForEntityForName:@"Attachment"
                                                                       inManagedObjectContext:self.testContext];
    att.attachmentId = [[NSUUID UUID] UUIDString];
    att.tenantId = self.testTenantId;
    att.ownerType = @"Order";
    att.ownerId = @"ord-att-owner-test";
    att.filename = @"test.png";
    att.mimeType = @"image/png";
    att.storagePathRelative = @"test/owner.png";
    att.capturedAt = [NSDate date];
    att.expiresAt = [NSDate dateWithTimeIntervalSinceNow:86400];
    att.hashStatus = CMAttachmentHashStatusPending;
    att.capturedByUserId = self.courierUser.userId;
    att.createdAt = [NSDate date];
    att.updatedAt = [NSDate date];
    att.version = 1;
    [self saveContext];

    NSError *err = nil;
    NSArray *atts = [repo attachmentsForOwner:@"Order" ownerId:@"ord-att-owner-test" error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(atts.count, 1);
}

// ── Notification Repository ────────────────────────────────────────────────

- (void)testNotificationRepository_AllForUser {
    [self switchToUser:self.courierUser];
    CMNotificationRepository *repo = [[CMNotificationRepository alloc] initWithContext:self.testContext];
    CMNotificationItem *item = [repo insertNotification];
    item.tenantId = self.testTenantId;
    item.templateKey = @"test.key";
    item.recipientUserId = self.courierUser.userId;
    item.status = CMNotificationStatusActive;
    item.rateLimitBucket = @"bucket-test";
    [self saveContext];

    NSError *err = nil;
    NSArray *items = [repo allForUser:self.courierUser.userId limit:0 error:&err];
    XCTAssertNil(err);
    XCTAssertGreaterThanOrEqual(items.count, 1);
}

// ── AuditRepository ────────────────────────────────────────────────────────

- (void)testAuditRepository_EntriesForTenant {
    [self switchToUser:self.adminUser];
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];

    NSError *err = nil;
    CMAuditEntry *latest = [repo latestEntryForTenant:self.testTenantId error:&err];
    // May be nil if no audit entries yet — that's fine.
    (void)latest;
    XCTAssertNil(err);
}

@end
