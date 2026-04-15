//
//  CMScoringEngineUpgradeTests.m
//  CourierMatch Integration Tests
//
//  Tests for rubric upgrade flow on CMScoringEngine (creates a new scorecard
//  linked to the previous version's scorecard).
//

#import "CMIntegrationTestCase.h"
#import "CMScoringEngine.h"
#import "CMDeliveryScorecard.h"
#import "CMRubricTemplate.h"
#import "CMOrder.h"
#import "CMAddress.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"

@interface CMScoringEngineUpgradeTests : CMIntegrationTestCase
@end

@implementation CMScoringEngineUpgradeTests

- (void)setUp {
    [super setUp];
    [self switchToUser:self.reviewerUser];
}

- (CMOrder *)seedDeliveredOrder:(NSString *)orderId {
    CMOrder *o = [self insertTestOrder:orderId];
    o.status = CMOrderStatusDelivered;
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    o.pickupWindowStart = [NSDate dateWithTimeIntervalSinceNow:-3600];
    o.pickupWindowEnd = [NSDate dateWithTimeIntervalSinceNow:-1800];
    o.dropoffWindowStart = [NSDate dateWithTimeIntervalSinceNow:-1800];
    o.dropoffWindowEnd = [NSDate dateWithTimeIntervalSinceNow:-300];
    o.updatedAt = [NSDate dateWithTimeIntervalSinceNow:-300];
    [self saveContext];
    return o;
}

- (void)testCheckRubricUpgradeNoActiveRubric {
    // No rubric exists yet
    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *fakeSc = [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                                                inManagedObjectContext:self.testContext];
    fakeSc.scorecardId = @"sc-no-rubric";
    fakeSc.tenantId = self.testTenantId;
    fakeSc.orderId = @"o-1";
    fakeSc.courierId = @"c-1";
    fakeSc.rubricId = @"missing";
    fakeSc.rubricVersion = 1;
    fakeSc.createdAt = [NSDate date];
    fakeSc.updatedAt = [NSDate date];
    fakeSc.version = 1;
    [self saveContext];

    NSDictionary *info = [engine checkRubricUpgradeAvailable:fakeSc];
    XCTAssertNotNil(info);
    XCTAssertFalse([info[CMRubricUpgradeAvailableKey] boolValue]);
}

- (void)testCheckRubricUpgradeSameVersion {
    CMRubricTemplate *r = [self insertTestRubric:@"r-up-1"];
    CMOrder *o = [self seedDeliveredOrder:@"ord-up-1"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:o courierId:o.assignedCourierId error:nil];
    XCTAssertNotNil(sc);

    NSDictionary *info = [engine checkRubricUpgradeAvailable:sc];
    XCTAssertNotNil(info);
    // Same rubric, same version — no upgrade
    XCTAssertFalse([info[CMRubricUpgradeAvailableKey] boolValue]);
}

- (void)testCheckRubricUpgradeNewerVersionAvailable {
    CMRubricTemplate *r1 = [self insertTestRubric:@"r-up-2"];
    CMOrder *o = [self seedDeliveredOrder:@"ord-up-2"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:o courierId:o.assignedCourierId error:nil];
    XCTAssertNotNil(sc);

    // Bump rubric version
    r1.rubricVersion = 5;
    r1.updatedAt = [NSDate date];
    [self saveContext];

    NSDictionary *info = [engine checkRubricUpgradeAvailable:sc];
    XCTAssertTrue([info[CMRubricUpgradeAvailableKey] boolValue]);
    XCTAssertEqual([info[CMRubricUpgradeLatestVersionKey] longLongValue], 5LL);
}

- (void)testUpgradeScorecardRubricCreatesSupersedingScorecard {
    CMRubricTemplate *r1 = [self insertTestRubric:@"r-up-3"];
    CMOrder *o = [self seedDeliveredOrder:@"ord-up-3"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *original = [engine createScorecardForOrder:o courierId:o.assignedCourierId error:nil];
    XCTAssertNotNil(original);

    // Bump rubric version
    r1.rubricVersion = 7;
    r1.updatedAt = [NSDate date];
    [self saveContext];

    NSError *err = nil;
    CMDeliveryScorecard *upgraded = [engine upgradeScorecardRubric:original error:&err];
    XCTAssertNotNil(upgraded, @"Upgrade should succeed: %@", err);
    XCTAssertEqualObjects(upgraded.supersedesScorecardId, original.scorecardId);
    XCTAssertEqual(upgraded.rubricVersion, 7);
}

- (void)testUpgradeFinalizedScorecardRejected {
    CMRubricTemplate *r1 = [self insertTestRubric:@"r-up-4"];
    CMOrder *o = [self seedDeliveredOrder:@"ord-up-4"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:o courierId:o.assignedCourierId error:nil];
    sc.finalizedAt = [NSDate date];
    sc.finalizedBy = self.reviewerUser.userId;
    [self saveContext];

    NSError *err = nil;
    CMDeliveryScorecard *upgraded = [engine upgradeScorecardRubric:sc error:&err];
    XCTAssertNil(upgraded);
    XCTAssertNotNil(err);
}

- (void)testUpgradeNoNewerVersionRejected {
    CMRubricTemplate *r1 = [self insertTestRubric:@"r-up-5"];
    CMOrder *o = [self seedDeliveredOrder:@"ord-up-5"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.testContext];
    CMDeliveryScorecard *sc = [engine createScorecardForOrder:o courierId:o.assignedCourierId error:nil];

    NSError *err = nil;
    CMDeliveryScorecard *upgraded = [engine upgradeScorecardRubric:sc error:&err];
    XCTAssertNil(upgraded);
    XCTAssertNotNil(err);
}

@end
