//
//  CMScoringEngineTests.m
//  CourierMatch Tests
//
//  Tests for the scoring engine: automatic scorers (on_time, photo_attached,
//  signature_captured), manual grading validation, and scorecard finalization.
//
//  Uses an in-memory Core Data stack with RubricTemplate, DeliveryScorecard,
//  Order, and Attachment entities.
//

#import <XCTest/XCTest.h>
#import "CMAutoScorer_OnTime.h"
#import "CMAutoScorer_PhotoAttached.h"
#import "CMAutoScorer_SignatureCaptured.h"
#import "CMAutoScorerProtocol.h"
#import "CMScoringEngine.h"
#import "CMDeliveryScorecard.h"
#import "CMRubricTemplate.h"
#import "CMOrder.h"
#import "CMAttachment.h"
#import "CMAddress.h"
#import "CMErrorCodes.h"
#import "CMTestCoreDataHelper.h"
#import "CMTenantContext.h"

@interface CMScoringEngineTests : XCTestCase
@property (nonatomic, strong) NSManagedObjectContext *ctx;
@end

@implementation CMScoringEngineTests

- (void)setUp {
    [super setUp];
    self.ctx = [CMTestCoreDataHelper inMemoryContext];
    // The scoring engine uses repositories that require a tenant context.
    // Manual grading and finalization require reviewer role.
    [[CMTenantContext shared] setUserId:@"test-user"
                               tenantId:@"test-tenant"
                                   role:@"reviewer"];
}

- (void)tearDown {
    [[CMTenantContext shared] clear];
    [super tearDown];
}

#pragma mark - Helpers

/// Creates a delivered order with a given delivery time relative to the dropoff window end.
- (CMOrder *)deliveredOrderWithDropoffWindowEnd:(NSDate *)dropoffEnd
                            deliveredAtOffset:(NSTimeInterval)offsetSeconds {
    CMAddress *pickup = [CMTestCoreDataHelper addressWithLat:40.0 lng:-74.0 zip:@"10001"];
    CMAddress *dropoff = [CMTestCoreDataHelper addressWithLat:40.1 lng:-74.1 zip:@"10002"];

    NSDate *dwStart = [dropoffEnd dateByAddingTimeInterval:-3600.0];
    NSDate *actualDeliveryTime = [dropoffEnd dateByAddingTimeInterval:offsetSeconds];

    CMOrder *order = [CMTestCoreDataHelper insertOrderInContext:self.ctx
                                                       orderId:[[NSUUID UUID] UUIDString]
                                                      tenantId:@"test-tenant"
                                                 pickupAddress:pickup
                                                dropoffAddress:dropoff
                                             pickupWindowStart:[NSDate dateWithTimeIntervalSince1970:1700000000]
                                               pickupWindowEnd:[NSDate dateWithTimeIntervalSince1970:1700003600]
                                            dropoffWindowStart:dwStart
                                              dropoffWindowEnd:dropoffEnd
                                                  parcelVolume:10.0
                                                  parcelWeight:10.0
                                           requiresVehicleType:nil
                                                        status:@"delivered"];
    order.updatedAt = actualDeliveryTime;
    return order;
}

/// Creates a test attachment with given properties.
- (CMAttachment *)attachmentWithMimeType:(NSString *)mimeType
                               ownerType:(NSString *)ownerType
                                 ownerId:(NSString *)ownerId
                                filename:(NSString *)filename {
    return [CMTestCoreDataHelper insertAttachmentInContext:self.ctx
                                             attachmentId:[[NSUUID UUID] UUIDString]
                                                 tenantId:@"test-tenant"
                                                ownerType:ownerType
                                                  ownerId:ownerId
                                                 filename:filename
                                                 mimeType:mimeType
                                                sizeBytes:1024];
}

/// Creates a rubric with one automatic item and one manual item.
- (CMRubricTemplate *)standardRubric {
    NSArray *items = @[
        @{
            @"itemKey": @"on_time",
            @"label": @"On Time",
            @"mode": @"automatic",
            @"maxPoints": @(10.0),
            @"autoEvaluator": @"on_time_within_10min"
        },
        @{
            @"itemKey": @"professionalism",
            @"label": @"Professionalism",
            @"mode": @"manual",
            @"maxPoints": @(20.0),
            @"instructions": @"Rate the courier's professionalism"
        }
    ];
    return [CMTestCoreDataHelper insertRubricInContext:self.ctx
                                             rubricId:@"rubric-1"
                                             tenantId:@"test-tenant"
                                                 name:@"Standard Rubric"
                                               active:YES
                                        rubricVersion:1
                                                items:items];
}

/// Creates a scorecard linked to the standard rubric.
- (CMDeliveryScorecard *)scorecardForOrder:(NSString *)orderId {
    return [CMTestCoreDataHelper insertScorecardInContext:self.ctx
                                             scorecardId:[[NSUUID UUID] UUIDString]
                                                 orderId:orderId
                                               courierId:@"courier-1"
                                                rubricId:@"rubric-1"
                                           rubricVersion:1];
}

#pragma mark - Auto Scorer: on_time_within_10min

- (void)testOnTime_Delivered5MinBefore_FullPoints {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:dropoffEnd
                                          deliveredAtOffset:-300.0]; // 5 min before

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNotNil(result);
    XCTAssertNil(error);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"Delivered 5 min before window end should get full points");
}

- (void)testOnTime_DeliveredExactlyAtWindowEnd_FullPoints {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:dropoffEnd
                                          deliveredAtOffset:0.0]; // exactly at window end

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"Delivered exactly at window end should get full points");
}

- (void)testOnTime_Delivered10MinAfter_FullPoints {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:dropoffEnd
                                          deliveredAtOffset:600.0]; // 10 min after

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"Delivered 10 min after window end should get full points (within tolerance)");
}

- (void)testOnTime_Delivered11MinAfter_ZeroPoints {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:dropoffEnd
                                          deliveredAtOffset:660.0]; // 11 min after

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 0.0, 0.001,
        @"Delivered 11 min after window end should get 0 points");
}

- (void)testOnTime_NotDelivered_ZeroPoints {
    // Create an order that is NOT delivered.
    CMAddress *pickup = [CMTestCoreDataHelper addressWithLat:40.0 lng:-74.0 zip:@"10001"];
    CMAddress *dropoff = [CMTestCoreDataHelper addressWithLat:40.1 lng:-74.1 zip:@"10002"];
    NSDate *dwEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];

    CMOrder *order = [CMTestCoreDataHelper insertOrderInContext:self.ctx
                                                       orderId:[[NSUUID UUID] UUIDString]
                                                      tenantId:@"test-tenant"
                                                 pickupAddress:pickup
                                                dropoffAddress:dropoff
                                             pickupWindowStart:[NSDate dateWithTimeIntervalSince1970:1700000000]
                                               pickupWindowEnd:[NSDate dateWithTimeIntervalSince1970:1700003600]
                                            dropoffWindowStart:[dwEnd dateByAddingTimeInterval:-3600]
                                              dropoffWindowEnd:dwEnd
                                                  parcelVolume:10.0
                                                  parcelWeight:10.0
                                           requiresVehicleType:nil
                                                        status:@"picked_up"]; // not delivered

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    // Should return nil (error) because order is not in delivered status.
    XCTAssertNil(result, @"Non-delivered order should produce nil result (error)");
    XCTAssertNotNil(error, @"Error should be set for non-delivered order");
}

#pragma mark - Auto Scorer: photo_attached

- (void)testPhotoAttached_JPEGExists_FullPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];
    CMAttachment *att = [self attachmentWithMimeType:@"image/jpeg"
                                           ownerType:@"Order"
                                             ownerId:order.orderId
                                            filename:@"photo.jpg"];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"image/jpeg attachment should yield full points");
}

- (void)testPhotoAttached_PNGExists_FullPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];
    CMAttachment *att = [self attachmentWithMimeType:@"image/png"
                                           ownerType:@"Order"
                                             ownerId:order.orderId
                                            filename:@"photo.png"];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"image/png attachment should yield full points");
}

- (void)testPhotoAttached_OnlyPDFAttachment_ZeroPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];
    CMAttachment *att = [self attachmentWithMimeType:@"application/pdf"
                                           ownerType:@"Order"
                                             ownerId:order.orderId
                                            filename:@"doc.pdf"];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 0.0, 0.001,
        @"Only application/pdf attachment should yield 0 points for photo check");
}

- (void)testPhotoAttached_NoAttachments_ZeroPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 0.0, 0.001,
        @"No attachments should yield 0 points");
}

#pragma mark - Auto Scorer: signature_captured

- (void)testSignatureCaptured_SignatureOwnerType_FullPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];
    CMAttachment *att = [self attachmentWithMimeType:@"image/png"
                                           ownerType:@"signature"
                                             ownerId:order.orderId
                                            filename:@"sig.png"];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
        @"Attachment with ownerType 'signature' should yield full points");
}

- (void)testSignatureCaptured_NoSignatureAttachment_ZeroPoints {
    CMOrder *order = [self deliveredOrderWithDropoffWindowEnd:[NSDate date] deliveredAtOffset:0];
    CMAttachment *att = [self attachmentWithMimeType:@"image/jpeg"
                                           ownerType:@"Order"
                                             ownerId:order.orderId
                                            filename:@"photo.jpg"];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:&error];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 0.0, 0.001,
        @"No signature attachment should yield 0 points");
}

#pragma mark - Manual Grading

- (void)testManualGrade_PointsWithinBoundsAccepted {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-1"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:15.0
                                  notes:nil
                                  error:&error];

    XCTAssertTrue(ok, @"Points within bounds (15/20) should be accepted");
    XCTAssertNil(error);
}

- (void)testManualGrade_PointsAboveMaxRejected {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-2"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:25.0 // above maxPoints of 20
                                  notes:nil
                                  error:&error];

    XCTAssertFalse(ok, @"Points above maxPoints should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

- (void)testManualGrade_PointsBelowZeroRejected {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-3"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:-1.0
                                  notes:@"some notes"
                                  error:&error];

    XCTAssertFalse(ok, @"Negative points should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

- (void)testManualGrade_BelowHalfWithoutNotesRejected {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-4"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    // maxPoints=20, half=10. Points=5 < 10, no notes -> rejected.
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:5.0
                                  notes:nil
                                  error:&error];

    XCTAssertFalse(ok,
        @"Points below half of maxPoints without notes should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

- (void)testManualGrade_BelowHalfWithNotesAccepted {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-5"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:5.0
                                  notes:@"Courier was rude to customer"
                                  error:&error];

    XCTAssertTrue(ok,
        @"Points below half with notes should be accepted");
    XCTAssertNil(error);
}

#pragma mark - Finalization

- (void)testFinalize_AllItemsGraded_Succeeds {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-6"];

    // Simulate that automatic result for "on_time" already exists.
    scorecard.automatedResults = @[
        @{@"itemKey": @"on_time", @"points": @(10.0), @"maxPoints": @(10.0), @"evidence": @"ok"}
    ];

    // Grade the manual item.
    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    [engine recordManualGrade:scorecard
                      itemKey:@"professionalism"
                       points:18.0
                        notes:nil
                        error:&error];
    XCTAssertNil(error);

    // Finalize.
    error = nil;
    BOOL ok = [engine finalizeScorecard:scorecard error:&error];
    XCTAssertTrue(ok, @"Finalization with all items graded should succeed");
    XCTAssertNil(error);
    XCTAssertNotNil(scorecard.finalizedAt,
        @"finalizedAt should be set after successful finalization");
}

- (void)testFinalize_MissingGrades_Fails {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-7"];

    // Automatic result present, but manual grade missing.
    scorecard.automatedResults = @[
        @{@"itemKey": @"on_time", @"points": @(10.0), @"maxPoints": @(10.0), @"evidence": @"ok"}
    ];
    // manualResults is empty -> missing "professionalism" grade.

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine finalizeScorecard:scorecard error:&error];

    XCTAssertFalse(ok, @"Finalization with missing grades should fail");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

- (void)testFinalize_AlreadyFinalized_Error {
    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-8"];

    // Mark as already finalized.
    scorecard.finalizedAt = [NSDate date];
    scorecard.finalizedBy = @"admin-1";

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine finalizeScorecard:scorecard error:&error];

    XCTAssertFalse(ok, @"Already finalized scorecard should fail");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeScorecardAlreadyFinalized,
        @"Error code should be CMErrorCodeScorecardAlreadyFinalized");
}

#pragma mark - Role Enforcement: Manual Grading Denied for Courier

- (void)testManualGrade_CourierRole_Denied {
    [[CMTenantContext shared] setUserId:@"test-courier"
                               tenantId:@"test-tenant"
                                   role:@"courier"];

    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-role-1"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:15.0
                                  notes:nil
                                  error:&error];

    XCTAssertFalse(ok, @"Courier should not be allowed to record manual grades");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodePermissionDenied);
}

- (void)testManualGrade_DispatcherRole_Denied {
    [[CMTenantContext shared] setUserId:@"test-dispatcher"
                               tenantId:@"test-tenant"
                                   role:@"dispatcher"];

    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-role-2"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:15.0
                                  notes:nil
                                  error:&error];

    XCTAssertFalse(ok, @"Dispatcher should not be allowed to record manual grades");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodePermissionDenied);
}

#pragma mark - Role Enforcement: Finalization Denied for Courier

- (void)testFinalize_CourierRole_Denied {
    [[CMTenantContext shared] setUserId:@"test-courier"
                               tenantId:@"test-tenant"
                                   role:@"courier"];

    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-role-3"];
    scorecard.automatedResults = @[
        @{@"itemKey": @"on_time", @"points": @(10.0), @"maxPoints": @(10.0), @"evidence": @"ok"}
    ];
    scorecard.manualResults = @[
        @{@"itemKey": @"professionalism", @"points": @(15.0), @"maxPoints": @(20.0), @"notes": @"ok"}
    ];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine finalizeScorecard:scorecard error:&error];

    XCTAssertFalse(ok, @"Courier should not be allowed to finalize scorecards");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodePermissionDenied);
}

- (void)testFinalize_DispatcherRole_Denied {
    [[CMTenantContext shared] setUserId:@"test-dispatcher"
                               tenantId:@"test-tenant"
                                   role:@"dispatcher"];

    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-role-4"];
    scorecard.automatedResults = @[
        @{@"itemKey": @"on_time", @"points": @(10.0), @"maxPoints": @(10.0), @"evidence": @"ok"}
    ];
    scorecard.manualResults = @[
        @{@"itemKey": @"professionalism", @"points": @(15.0), @"maxPoints": @(20.0), @"notes": @"ok"}
    ];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine finalizeScorecard:scorecard error:&error];

    XCTAssertFalse(ok, @"Dispatcher should not be allowed to finalize scorecards");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodePermissionDenied);
}

#pragma mark - Role Enforcement: Admin Can Grade and Finalize

- (void)testManualGrade_AdminRole_Allowed {
    [[CMTenantContext shared] setUserId:@"test-admin"
                               tenantId:@"test-tenant"
                                   role:@"admin"];

    [self standardRubric];
    CMDeliveryScorecard *scorecard = [self scorecardForOrder:@"order-role-5"];

    CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:self.ctx];
    NSError *error = nil;
    BOOL ok = [engine recordManualGrade:scorecard
                                itemKey:@"professionalism"
                                 points:15.0
                                  notes:nil
                                  error:&error];

    XCTAssertTrue(ok, @"Admin should be allowed to record manual grades");
    XCTAssertNil(error);
}

@end
