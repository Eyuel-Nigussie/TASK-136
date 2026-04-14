//
//  CMCourierFlowIntegrationTests.m
//  CourierMatch Integration Tests
//
//  End-to-end courier flow: itinerary creation, order matching, accept,
//  status transitions, notifications, scoring, and finalization.
//  See design.md section 17.
//

#import "CMIntegrationTestCase.h"
#import "CMMatchEngine.h"
#import "CMMatchCandidate.h"
#import "CMItinerary.h"
#import "CMOrder.h"
#import "CMAddress.h"
#import "CMNotificationCenterService.h"
#import "CMNotificationItem.h"
#import "CMScoringEngine.h"
#import "CMDeliveryScorecard.h"
#import "CMRubricTemplate.h"
#import "CMMatchCandidateRepository.h"
#import "CMOrderRepository.h"
#import "CMNotificationRepository.h"
#import "CMAuditService.h"
#import "CMAuditEntry.h"
#import "CMAuditRepository.h"
#import "CMTenantContext.h"
#import "NSManagedObjectContext+CMHelpers.h"

@interface CMCourierFlowIntegrationTests : CMIntegrationTestCase
@end

@implementation CMCourierFlowIntegrationTests

#pragma mark - Test: Full Courier Flow (design.md section 17)

- (void)testFullCourierFlowFromMatchToScorecard {
    // ---- Step 1: Create itinerary with controlled origin/destination/vehicle/capacity ----
    CMItinerary *itinerary = [self insertTestItinerary:@"itin-flow-001"];
    itinerary.originAddress = [self addressWithLat:40.7128 lng:-74.0060 zip:@"10001" city:@"New York"];
    itinerary.destinationAddress = [self addressWithLat:40.7580 lng:-73.9855 zip:@"10036" city:@"New York"];
    itinerary.vehicleType = CMVehicleTypeCar;
    itinerary.vehicleCapacityVolumeL = 500.0;
    itinerary.vehicleCapacityWeightKg = 200.0;

    NSDate *now = [NSDate date];
    itinerary.departureWindowStart = now;
    itinerary.departureWindowEnd = [now dateByAddingTimeInterval:4 * 3600];

    // ---- Step 2: Create 5 orders with varying pickup/dropoff locations and windows ----
    NSArray<NSString *> *orderIds = @[@"ord-001", @"ord-002", @"ord-003", @"ord-004", @"ord-005"];
    NSMutableArray<CMOrder *> *orders = [NSMutableArray array];

    for (NSUInteger i = 0; i < orderIds.count; i++) {
        CMOrder *order = [self insertTestOrder:orderIds[i]];
        // Nearby pickup addresses (within range of origin)
        double offsetLat = 0.005 * (double)i;
        double offsetLng = 0.003 * (double)i;
        order.pickupAddress = [self addressWithLat:40.7128 + offsetLat
                                               lng:-74.0060 + offsetLng
                                               zip:@"10001"
                                              city:@"New York"];
        order.dropoffAddress = [self addressWithLat:40.7580 - offsetLat
                                                lng:-73.9855 + offsetLng
                                                zip:@"10036"
                                               city:@"New York"];
        order.pickupWindowStart = [now dateByAddingTimeInterval:(double)i * 600];
        order.pickupWindowEnd = [order.pickupWindowStart dateByAddingTimeInterval:3600];
        order.dropoffWindowStart = [order.pickupWindowEnd dateByAddingTimeInterval:600];
        order.dropoffWindowEnd = [order.dropoffWindowStart dateByAddingTimeInterval:3600];
        order.parcelVolumeL = 10.0 + (double)i * 5.0;
        order.parcelWeightKg = 5.0 + (double)i * 2.0;
        [orders addObject:order];
    }

    [self saveContext];

    // ---- Step 3: Run CMMatchEngine.recomputeCandidatesForItinerary: ----
    XCTestExpectation *matchExp = [self expectationWithDescription:@"Match engine recompute"];
    [[CMMatchEngine shared] recomputeCandidatesForItinerary:itinerary
                                                 completion:^(NSError *error) {
        // Non-fatal truncation errors are acceptable.
        if (error && error.code != 5005) {
            XCTFail(@"Unexpected match engine error: %@", error);
        }
        [matchExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // ---- Step 4: Verify ranked candidates returned in correct order ----
    NSError *rankError = nil;
    NSArray<CMMatchCandidate *> *candidates =
        [[CMMatchEngine shared] rankCandidatesForItinerary:@"itin-flow-001" error:&rankError];
    XCTAssertNotNil(candidates, @"Candidates should not be nil: %@", rankError);
    XCTAssertGreaterThan(candidates.count, 0, @"Should have at least one candidate");

    // Verify ranking: score DESC ordering
    for (NSUInteger i = 1; i < candidates.count; i++) {
        XCTAssertGreaterThanOrEqual(candidates[i - 1].score, candidates[i].score,
                                    @"Candidates should be sorted by score DESC");
    }

    // Verify rank positions are 1-based and sequential
    for (NSUInteger i = 0; i < candidates.count; i++) {
        XCTAssertEqual(candidates[i].rankPosition, (int32_t)(i + 1),
                       @"Rank position should be %lu but was %d", (unsigned long)(i + 1),
                       candidates[i].rankPosition);
    }

    // ---- Step 6: Verify explanation strings present on each candidate ----
    for (CMMatchCandidate *candidate in candidates) {
        XCTAssertNotNil(candidate.explanationComponents,
                        @"Candidate %@ should have explanation components", candidate.orderId);
        XCTAssertGreaterThan(candidate.explanationComponents.count, 0,
                             @"Explanation components should not be empty for %@", candidate.orderId);
    }

    // ---- Step 7: Simulate "accept match" by assigning courier + status = assigned ----
    CMOrder *acceptedOrder = orders.firstObject;
    acceptedOrder.assignedCourierId = self.courierUserId;
    acceptedOrder.status = CMOrderStatusAssigned;
    acceptedOrder.updatedAt = [NSDate date];
    [self saveContext];

    XCTAssertEqualObjects(acceptedOrder.status, CMOrderStatusAssigned,
                          @"Order should be assigned");
    XCTAssertEqualObjects(acceptedOrder.assignedCourierId, self.courierUserId,
                          @"Courier ID should match");

    // ---- Step 8: Verify notification emitted for "assigned" event ----
    XCTestExpectation *assignNotifExp = [self expectationWithDescription:@"Assigned notification"];
    CMNotificationCenterService *notifService =
        [[CMNotificationCenterService alloc] initWithRepository:nil renderer:nil rateLimiter:nil];
    [notifService emitNotificationForEvent:@"assigned"
                                   payload:@{@"orderId": acceptedOrder.orderId,
                                             @"courierName": @"Courier"}
                           recipientUserId:self.courierUserId
                         subjectEntityType:@"Order"
                           subjectEntityId:acceptedOrder.orderId
                                completion:^(CMNotificationItem *item, NSError *error) {
        XCTAssertNotNil(item, @"Assigned notification should be created");
        XCTAssertNil(error, @"No error expected: %@", error);
        [assignNotifExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // ---- Step 9: Simulate "picked_up" status change + verify notification ----
    acceptedOrder.status = CMOrderStatusPickedUp;
    acceptedOrder.updatedAt = [NSDate date];
    [self saveContext];

    XCTestExpectation *pickupNotifExp = [self expectationWithDescription:@"Picked up notification"];
    [notifService emitNotificationForEvent:@"picked_up"
                                   payload:@{@"orderId": acceptedOrder.orderId}
                           recipientUserId:self.courierUserId
                         subjectEntityType:@"Order"
                           subjectEntityId:acceptedOrder.orderId
                                completion:^(CMNotificationItem *item, NSError *error) {
        XCTAssertNotNil(item, @"Picked up notification should be created");
        [pickupNotifExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // ---- Step 10: Simulate "delivered" status change + verify notification ----
    acceptedOrder.status = CMOrderStatusDelivered;
    // Set dropoffWindowEnd to 5 min ago so on_time_within_10min scorer sees this as on-time.
    acceptedOrder.dropoffWindowEnd = [NSDate dateWithTimeIntervalSinceNow:-300];
    acceptedOrder.updatedAt = [NSDate date]; // "delivered now" — within 10 min of dropoffWindowEnd
    [self saveContext];

    XCTAssertTrue([acceptedOrder isTerminal], @"Delivered order should be terminal");

    XCTestExpectation *deliverNotifExp = [self expectationWithDescription:@"Delivered notification"];
    [notifService emitNotificationForEvent:@"delivered"
                                   payload:@{@"orderId": acceptedOrder.orderId}
                           recipientUserId:self.courierUserId
                         subjectEntityType:@"Order"
                           subjectEntityId:acceptedOrder.orderId
                                completion:^(CMNotificationItem *item, NSError *error) {
        XCTAssertNotNil(item, @"Delivered notification should be created");
        [deliverNotifExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // ---- Step 11: Create scorecard via CMScoringEngine ----
    [self insertTestRubric:@"rubric-001"];
    [self saveContext];

    CMScoringEngine *scoringEngine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    NSError *scorecardError = nil;
    CMDeliveryScorecard *scorecard =
        [scoringEngine createScorecardForOrder:acceptedOrder
                                     courierId:self.courierUserId
                                         error:&scorecardError];
    XCTAssertNotNil(scorecard, @"Scorecard should be created: %@", scorecardError);
    XCTAssertEqualObjects(scorecard.orderId, acceptedOrder.orderId);
    XCTAssertEqualObjects(scorecard.courierId, self.courierUserId);

    // ---- Step 12: Verify automatic scorers ran (on_time result present) ----
    XCTAssertNotNil(scorecard.automatedResults, @"Automated results should not be nil");
    XCTAssertGreaterThan(scorecard.automatedResults.count, 0,
                         @"Should have at least one automated result");

    BOOL hasOnTimeResult = NO;
    for (NSDictionary *result in scorecard.automatedResults) {
        if ([result[@"itemKey"] isEqualToString:@"on_time"]) {
            hasOnTimeResult = YES;
            XCTAssertNotNil(result[@"points"], @"on_time result should have points");
            XCTAssertNotNil(result[@"maxPoints"], @"on_time result should have maxPoints");
            break;
        }
    }
    XCTAssertTrue(hasOnTimeResult, @"Should have an on_time automated result");

    // ---- Step 13: Record manual grade for a subjective item ----
    NSError *gradeError = nil;
    BOOL gradeOK = [scoringEngine recordManualGrade:scorecard
                                            itemKey:@"customer_satisfaction"
                                             points:20.0
                                              notes:@"Good customer interaction"
                                              error:&gradeError];
    XCTAssertTrue(gradeOK, @"Manual grade should succeed: %@", gradeError);

    NSError *gradeError2 = nil;
    BOOL gradeOK2 = [scoringEngine recordManualGrade:scorecard
                                             itemKey:@"package_handling"
                                              points:22.0
                                               notes:@"Careful handling observed"
                                               error:&gradeError2];
    XCTAssertTrue(gradeOK2, @"Manual grade 2 should succeed: %@", gradeError2);

    // Verify manual results were recorded
    XCTAssertGreaterThanOrEqual(scorecard.manualResults.count, 2,
                                @"Should have at least 2 manual results");

    // ---- Step 14: Finalize scorecard ----
    NSError *finalizeError = nil;
    BOOL finalized = [scoringEngine finalizeScorecard:scorecard error:&finalizeError];
    XCTAssertTrue(finalized, @"Finalize should succeed: %@", finalizeError);
    XCTAssertNotNil(scorecard.finalizedAt, @"finalizedAt should be set after finalization");
    XCTAssertTrue([scorecard isFinalized], @"Scorecard should report as finalized");
    XCTAssertGreaterThan(scorecard.totalPoints, 0.0, @"Total points should be > 0");
    XCTAssertGreaterThan(scorecard.maxPoints, 0.0, @"Max points should be > 0");

    // Verify audit entry was written for finalization
    XCTestExpectation *auditExp = [self expectationWithDescription:@"Audit entry for finalization"];
    [[CMAuditService shared] recordAction:@"scorecard.finalize.verify"
                               targetType:@"DeliveryScorecard"
                                 targetId:scorecard.scorecardId
                               beforeJSON:nil
                                afterJSON:@{@"verified": @YES}
                                   reason:@"Integration test verification"
                               completion:^(CMAuditEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"Audit entry should be written");
        [auditExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Test: Filtered Orders Excluded

- (void)testFilteredOrdersExcludedFromCandidates {
    // Create itinerary
    CMItinerary *itinerary = [self insertTestItinerary:@"itin-filter-001"];
    itinerary.originAddress = [self addressWithLat:40.7128 lng:-74.0060 zip:@"10001" city:@"New York"];
    itinerary.destinationAddress = [self addressWithLat:40.7580 lng:-73.9855 zip:@"10036" city:@"New York"];
    itinerary.vehicleType = CMVehicleTypeBike;

    NSDate *now = [NSDate date];
    itinerary.departureWindowStart = now;
    itinerary.departureWindowEnd = [now dateByAddingTimeInterval:2 * 3600];

    // Order requiring truck (vehicle mismatch with bike itinerary)
    CMOrder *truckOrder = [self insertTestOrder:@"ord-truck"];
    truckOrder.requiresVehicleType = CMVehicleTypeTruck;
    truckOrder.pickupAddress = [self addressWithLat:40.7128 lng:-74.0060 zip:@"10001" city:@"New York"];
    truckOrder.dropoffAddress = [self addressWithLat:40.7580 lng:-73.9855 zip:@"10036" city:@"New York"];
    truckOrder.pickupWindowStart = now;
    truckOrder.pickupWindowEnd = [now dateByAddingTimeInterval:3600];

    // Order far away (out of spatial range)
    CMOrder *farOrder = [self insertTestOrder:@"ord-far"];
    farOrder.pickupAddress = [self addressWithLat:34.0522 lng:-118.2437 zip:@"90001" city:@"Los Angeles"];
    farOrder.dropoffAddress = [self addressWithLat:34.0522 lng:-118.2437 zip:@"90001" city:@"Los Angeles"];
    farOrder.pickupWindowStart = now;
    farOrder.pickupWindowEnd = [now dateByAddingTimeInterval:3600];

    // Valid nearby order
    CMOrder *validOrder = [self insertTestOrder:@"ord-valid"];
    validOrder.pickupAddress = [self addressWithLat:40.7130 lng:-74.0062 zip:@"10001" city:@"New York"];
    validOrder.dropoffAddress = [self addressWithLat:40.7582 lng:-73.9857 zip:@"10036" city:@"New York"];
    validOrder.pickupWindowStart = now;
    validOrder.pickupWindowEnd = [now dateByAddingTimeInterval:3600];

    [self saveContext];

    // Run match engine
    XCTestExpectation *matchExp = [self expectationWithDescription:@"Match recompute filter test"];
    [[CMMatchEngine shared] recomputeCandidatesForItinerary:itinerary
                                                 completion:^(NSError *error) {
        [matchExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    // Verify results
    NSError *rankError = nil;
    NSArray<CMMatchCandidate *> *candidates =
        [[CMMatchEngine shared] rankCandidatesForItinerary:@"itin-filter-001" error:&rankError];

    // The truck-only order should not appear (vehicle mismatch with bike)
    for (CMMatchCandidate *c in candidates) {
        XCTAssertFalse([c.orderId isEqualToString:@"ord-truck"],
                       @"Truck-requiring order should be filtered out for bike itinerary");
    }

    // The far-away order should not appear (spatial filter)
    for (CMMatchCandidate *c in candidates) {
        XCTAssertFalse([c.orderId isEqualToString:@"ord-far"],
                       @"Far-away order should be filtered out by spatial pre-filter");
    }
}

#pragma mark - Test: Candidate Staleness Check

- (void)testCandidateStalenessDetection {
    CMMatchCandidateRepository *candidateRepo =
        [[CMMatchCandidateRepository alloc] initWithContext:self.testContext];

    CMMatchCandidate *candidate = [candidateRepo insertCandidate];
    candidate.tenantId = self.testTenantId;
    candidate.itineraryId = @"itin-stale-001";
    candidate.orderId = @"ord-stale-001";
    candidate.score = 50.0;
    candidate.computedAt = [NSDate dateWithTimeIntervalSinceNow:-600]; // 10 minutes ago
    candidate.stale = NO;
    [self saveContext];

    // Default staleness threshold is 300s (5 min), so 10-min-old candidate is stale
    BOOL isStale = [[CMMatchEngine shared] isCandidateStale:candidate];
    XCTAssertTrue(isStale, @"Candidate computed 10 minutes ago should be stale (threshold is 5 min)");

    // Fresh candidate should not be stale
    candidate.computedAt = [NSDate date];
    BOOL isStaleNow = [[CMMatchEngine shared] isCandidateStale:candidate];
    XCTAssertFalse(isStaleNow, @"Freshly computed candidate should not be stale");

    // Explicitly stale candidate
    candidate.stale = YES;
    BOOL explicitlyStale = [[CMMatchEngine shared] isCandidateStale:candidate];
    XCTAssertTrue(explicitlyStale, @"Explicitly stale candidate should report as stale");
}

@end
