//
//  CMAppealServiceEdgeCaseTests.m
//  CourierMatch Integration Tests
//
//  Tests for CMAppealService error and edge-case paths not covered
//  by CMDisputeAppealIntegrationTests (which focuses on the happy path).
//

#import "CMIntegrationTestCase.h"
#import "CMAppealService.h"
#import "CMAppeal.h"
#import "CMDispute.h"
#import "CMDeliveryScorecard.h"
#import "CMScoringEngine.h"
#import "CMOrder.h"
#import "CMAppealRepository.h"
#import "CMScorecardRepository.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"
#import "CMErrorCodes.h"

@interface CMAppealServiceEdgeCaseTests : CMIntegrationTestCase
@property (nonatomic, strong) CMAppealService *service;
@property (nonatomic, strong) CMDeliveryScorecard *finalizedScorecard;
@property (nonatomic, strong) CMAppeal *openAppeal;
@end

@implementation CMAppealServiceEdgeCaseTests

- (void)setUp {
    [super setUp];
    self.service = [[CMAppealService alloc] initWithContext:self.testContext];

    // Create a finalized scorecard as the prerequisite for opening appeals.
    [self setupFinalizedScorecardAndAppeal];
}

/// Creates a finalized scorecard and an open appeal in the reviewer's context.
- (void)setupFinalizedScorecardAndAppeal {
    CMOrder *order = [self insertTestOrder:@"appeal-edge-order"];
    order.status = @"delivered";
    order.assignedCourierId = self.courierUser.userId;
    order.pickupAddress = [self addressWithLat:40.7128 lng:-74.0060 zip:@"10001" city:@"NY"];
    order.dropoffAddress = [self addressWithLat:40.758 lng:-73.985 zip:@"10036" city:@"NY"];
    order.pickupWindowStart = [NSDate dateWithTimeIntervalSinceNow:-7200];
    order.pickupWindowEnd = [NSDate dateWithTimeIntervalSinceNow:-3600];
    order.dropoffWindowStart = [NSDate dateWithTimeIntervalSinceNow:-3600];
    order.dropoffWindowEnd = [NSDate dateWithTimeIntervalSinceNow:-600];
    order.updatedAt = [NSDate dateWithTimeIntervalSinceNow:-300];
    [self insertTestRubric:@"rubric-edge"];
    [self saveContext];

    [self switchToUser:self.reviewerUser];
    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    NSError *err = nil;
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:order
                                                   courierId:self.courierUser.userId
                                                       error:&err];
    if (!sc) { return; }
    [engine recordManualGrade:sc itemKey:@"customer_satisfaction" points:20 notes:@"ok" error:nil];
    [engine recordManualGrade:sc itemKey:@"package_handling" points:22 notes:@"ok" error:nil];
    [engine finalizeScorecard:sc error:nil];
    [self saveContext];
    self.finalizedScorecard = sc;

    // Open an appeal as courier
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    NSError *appealErr = nil;
    CMAppeal *appeal = [self.service openAppeal:nil
                                      scorecard:sc
                                         reason:@"Disputing score"
                                          error:&appealErr];
    self.openAppeal = appeal;
}

#pragma mark - openAppeal Error Paths

- (void)testOpenAppeal_NonFinalizedScorecard_Fails {
    // Create a non-finalized scorecard
    [self switchToUser:self.reviewerUser];
    CMOrder *order = [self insertTestOrder:@"non-final-order"];
    order.status = @"delivered";
    order.assignedCourierId = self.courierUser.userId;
    order.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NY"];
    order.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NY"];
    [self saveContext];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    NSError *err = nil;
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:order
                                                   courierId:self.courierUser.userId
                                                       error:&err];
    if (!sc) { return; }
    XCTAssertFalse([sc isFinalized], @"Scorecard should not be finalized yet");

    [self switchToUser:self.courierUser];
    NSError *appealErr = nil;
    CMAppeal *appeal = [self.service openAppeal:nil scorecard:sc reason:@"test" error:&appealErr];
    XCTAssertNil(appeal, @"Should not be able to open appeal against non-finalized scorecard");
    XCTAssertNotNil(appealErr);
    XCTAssertEqual(appealErr.code, CMErrorCodeValidationFailed);
}

- (void)testOpenAppeal_NoAuthentication_Fails {
    if (!self.finalizedScorecard) { return; }
    [[CMTenantContext shared] clear]; // no user logged in

    NSError *err = nil;
    CMAppeal *appeal = [self.service openAppeal:nil
                                       scorecard:self.finalizedScorecard
                                          reason:@"test"
                                           error:&err];
    XCTAssertNil(appeal);
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testOpenAppeal_CourierCannotAppealOtherCourierScorecard {
    if (!self.finalizedScorecard) { return; }
    // Dispatcher does not have appeals.open for other users
    [self switchToUser:self.dispatcherUser];
    NSError *err = nil;
    CMAppeal *appeal = [self.service openAppeal:nil
                                       scorecard:self.finalizedScorecard
                                          reason:@"test"
                                           error:&err];
    XCTAssertNil(appeal, @"Dispatcher should not be able to open appeals");
    XCTAssertNotNil(err);
}

#pragma mark - submitDecision Error Paths

- (void)testSubmitDecision_InvalidDecisionString_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    self.openAppeal.assignedReviewerId = self.reviewerUser.userId;

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"invalid_decision"
                                   appeal:self.openAppeal
                               afterScores:nil
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok, @"Invalid decision string should fail");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testSubmitDecision_AlreadyDecided_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    self.openAppeal.assignedReviewerId = self.reviewerUser.userId;
    self.openAppeal.decision = @"uphold"; // already decided

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"uphold"
                                   appeal:self.openAppeal
                               afterScores:nil
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok, @"Already decided appeal should fail");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testSubmitDecision_NoAssignedReviewer_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    self.openAppeal.assignedReviewerId = nil; // no reviewer

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"uphold"
                                   appeal:self.openAppeal
                               afterScores:nil
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok, @"Appeal without assigned reviewer should fail");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testSubmitDecision_NoAuthentication_Fails {
    if (!self.openAppeal) { return; }
    self.openAppeal.assignedReviewerId = self.reviewerUser.userId;
    [[CMTenantContext shared] clear];

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"uphold"
                                   appeal:self.openAppeal
                               afterScores:nil
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok);
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testSubmitDecision_WrongReviewer_Fails {
    if (!self.openAppeal) { return; }
    // Assign a different reviewer, but submit as the original reviewer
    [self switchToUser:self.reviewerUser];
    self.openAppeal.assignedReviewerId = @"some-other-reviewer-id";

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"uphold"
                                   appeal:self.openAppeal
                               afterScores:nil
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok, @"Only assigned reviewer can submit decision");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testSubmitDecision_AdjustWithoutAfterScores_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    self.openAppeal.assignedReviewerId = self.reviewerUser.userId;

    NSError *err = nil;
    BOOL ok = [self.service submitDecision:@"adjust"
                                   appeal:self.openAppeal
                               afterScores:nil  // required for adjust
                                    notes:@"notes"
                                    error:&err];
    XCTAssertFalse(ok, @"'adjust' decision requires afterScores");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

#pragma mark - closeAppeal Error Paths

- (void)testCloseAppeal_WithoutDecision_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    // Appeal has no decision yet.
    XCTAssertNil(self.openAppeal.decision, @"Appeal should not have a decision");

    NSError *err = nil;
    BOOL ok = [self.service closeAppeal:self.openAppeal
                             resolution:@"resolved"
                                  error:&err];
    XCTAssertFalse(ok, @"Cannot close appeal without a decision");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testCloseAppeal_NoAuthentication_Fails {
    if (!self.openAppeal) { return; }
    self.openAppeal.decision = @"uphold";
    [[CMTenantContext shared] clear];

    NSError *err = nil;
    BOOL ok = [self.service closeAppeal:self.openAppeal
                             resolution:@"resolved"
                                  error:&err];
    XCTAssertFalse(ok);
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testCloseAppeal_WrongRole_Fails {
    if (!self.openAppeal) { return; }
    self.openAppeal.decision = @"uphold";
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];

    NSError *err = nil;
    BOOL ok = [self.service closeAppeal:self.openAppeal
                             resolution:@"resolved"
                                  error:&err];
    XCTAssertFalse(ok, @"Courier role cannot close appeals");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

#pragma mark - assignReviewer Error Paths

- (void)testAssignReviewer_AlreadyDecided_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];
    self.openAppeal.decision = @"uphold"; // mark as decided

    NSError *err = nil;
    BOOL ok = [self.service assignReviewer:self.reviewerUser.userId
                                  toAppeal:self.openAppeal
                                     error:&err];
    XCTAssertFalse(ok, @"Cannot assign reviewer to decided appeal");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testAssignReviewer_ReviewerNotFound_Fails {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];

    NSError *err = nil;
    BOOL ok = [self.service assignReviewer:@"nonexistent-reviewer-id"
                                  toAppeal:self.openAppeal
                                     error:&err];
    XCTAssertFalse(ok, @"Non-existent reviewer should fail");
    XCTAssertNotNil(err);
}

- (void)testAssignReviewer_WrongRole_CannotBeReviewer {
    if (!self.openAppeal) { return; }
    [self switchToUser:self.reviewerUser];

    // The courier user has role 'courier' which is not reviewer-eligible.
    NSError *err = nil;
    BOOL ok = [self.service assignReviewer:self.courierUser.userId
                                  toAppeal:self.openAppeal
                                     error:&err];
    XCTAssertFalse(ok, @"User with courier role cannot be assigned as reviewer");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

@end
