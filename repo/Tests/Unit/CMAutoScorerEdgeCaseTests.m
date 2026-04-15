//
//  CMAutoScorerEdgeCaseTests.m
//  CourierMatch Unit Tests
//
//  Covers branches in the three built-in auto-scorers that are NOT reached
//  by CMScoringEngineTests: nil-dropoffWindowEnd, nil-updatedAt, result key
//  presence, evidence string content, and case-insensitive ownerType matching.
//

#import <XCTest/XCTest.h>
#import "CMAutoScorer_OnTime.h"
#import "CMAutoScorer_PhotoAttached.h"
#import "CMAutoScorer_SignatureCaptured.h"
#import "CMAutoScorerProtocol.h"
#import "CMOrder.h"
#import "CMAttachment.h"
#import "CMAddress.h"
#import "CMErrorCodes.h"
#import "CMTestCoreDataHelper.h"

@interface CMAutoScorerEdgeCaseTests : XCTestCase
@property (nonatomic, strong) NSManagedObjectContext *ctx;
@end

@implementation CMAutoScorerEdgeCaseTests

- (void)setUp {
    [super setUp];
    self.ctx = [CMTestCoreDataHelper inMemoryContext];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

- (CMOrder *)deliveredOrderWithDropoffEnd:(NSDate *)dropoffEnd
                             deliveredAt:(NSDate *)deliveredAt {
    CMAddress *pickup  = [CMTestCoreDataHelper addressWithLat:40.0 lng:-74.0 zip:@"10001"];
    CMAddress *dropoff = [CMTestCoreDataHelper addressWithLat:40.1 lng:-74.1 zip:@"10002"];
    NSDate *dwStart = [dropoffEnd dateByAddingTimeInterval:-3600.0];

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
                                                  parcelWeight:5.0
                                           requiresVehicleType:nil
                                                        status:@"delivered"];
    order.updatedAt = deliveredAt;
    return order;
}

- (CMAttachment *)attachmentWithMimeType:(NSString *)mimeType
                               ownerType:(NSString *)ownerType
                                filename:(NSString *)filename {
    return [CMTestCoreDataHelper insertAttachmentInContext:self.ctx
                                             attachmentId:[[NSUUID UUID] UUIDString]
                                                 tenantId:@"test-tenant"
                                                ownerType:ownerType
                                                  ownerId:@"order-001"
                                                 filename:filename
                                                 mimeType:mimeType
                                                sizeBytes:2048];
}

// ---------------------------------------------------------------------------
#pragma mark - CMAutoScorer_OnTime: nil dropoffWindowEnd
// ---------------------------------------------------------------------------

- (void)testOnTime_NilDropoffWindowEnd_ReturnsNilWithError {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    order.dropoffWindowEnd = nil; // clear after construction

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNil(result,
                 @"nil dropoffWindowEnd must produce nil result");
    XCTAssertNotNil(error,
                    @"nil dropoffWindowEnd must produce a non-nil error");
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

- (void)testOnTime_NilDropoffWindowEnd_NilErrorPointer_DoesNotCrash {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    order.dropoffWindowEnd = nil;

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    XCTAssertNoThrow([scorer evaluateForOrder:order attachments:@[] error:NULL]);
}

// ---------------------------------------------------------------------------
#pragma mark - CMAutoScorer_OnTime: nil updatedAt
// ---------------------------------------------------------------------------

- (void)testOnTime_NilUpdatedAt_ReturnsNilWithError {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffEnd:dropoffEnd
                                           deliveredAt:dropoffEnd];
    order.updatedAt = nil; // clear after construction

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSError *error = nil;
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:&error];

    XCTAssertNil(result,
                 @"nil updatedAt must produce nil result");
    XCTAssertNotNil(error,
                    @"nil updatedAt must produce a non-nil error");
    XCTAssertEqual(error.code, CMErrorCodeValidationFailed);
}

// ---------------------------------------------------------------------------
#pragma mark - CMAutoScorer_OnTime: result key presence
// ---------------------------------------------------------------------------

- (void)testOnTime_OnTimeResult_HasExpectedKeys {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffEnd:dropoffEnd
                                           deliveredAt:dropoffEnd];

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];

    XCTAssertNotNil(result[CMAutoScorerResultPointsKey],
                    @"result must include points key");
    XCTAssertNotNil(result[CMAutoScorerResultMaxPointsKey],
                    @"result must include maxPoints key");
    XCTAssertNotNil(result[CMAutoScorerResultEvidenceKey],
                    @"result must include evidence key");
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultMaxPointsKey] doubleValue],
                               1.0, 0.001,
                               @"maxPoints for on_time scorer is 1.0");
}

- (void)testOnTime_LateResult_EvidenceContainsSecondsLate {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    // Deliver 660s (11 min) past window end — 60s past the 10-min tolerance.
    NSDate *deliveredAt = [dropoffEnd dateByAddingTimeInterval:660.0];
    CMOrder *order = [self deliveredOrderWithDropoffEnd:dropoffEnd
                                           deliveredAt:deliveredAt];

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    // The evidence string for late delivery contains "seconds past tolerance"
    XCTAssertTrue([evidence containsString:@"seconds past tolerance"],
                  @"Late-delivery evidence must mention 'seconds past tolerance'");
}

- (void)testOnTime_OnTimeResult_EvidenceContainsWithinTolerance {
    NSDate *dropoffEnd = [NSDate dateWithTimeIntervalSince1970:1700003600.0];
    CMOrder *order = [self deliveredOrderWithDropoffEnd:dropoffEnd
                                           deliveredAt:dropoffEnd];

    CMAutoScorer_OnTime *scorer = [[CMAutoScorer_OnTime alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    XCTAssertTrue([evidence containsString:@"within tolerance"],
                  @"On-time evidence must mention 'within tolerance'");
}

// ---------------------------------------------------------------------------
#pragma mark - CMAutoScorer_PhotoAttached: result keys + evidence
// ---------------------------------------------------------------------------

- (void)testPhotoAttached_WithPhoto_EvidenceContainsFilename {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    CMAttachment *att = [self attachmentWithMimeType:@"image/jpeg"
                                          ownerType:@"Order"
                                           filename:@"delivery_photo.jpg"];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    XCTAssertTrue([evidence containsString:@"delivery_photo.jpg"],
                  @"Evidence must contain the photo filename");
}

- (void)testPhotoAttached_NoPhoto_EvidenceDescribesAbsence {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];

    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    XCTAssertTrue([evidence containsString:@"No image"],
                  @"Absence evidence must mention 'No image'");
}

- (void)testPhotoAttached_ResultHasMaxPoints {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    CMAutoScorer_PhotoAttached *scorer = [[CMAutoScorer_PhotoAttached alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];
    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultMaxPointsKey] doubleValue],
                               1.0, 0.001);
}

// ---------------------------------------------------------------------------
#pragma mark - CMAutoScorer_SignatureCaptured: case-insensitive ownerType
// ---------------------------------------------------------------------------

- (void)testSignatureCaptured_UppercaseOwnerType_MatchesCaseInsensitive {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    // ownerType "SIGNATURE" — the scorer uses lowercaseString for comparison.
    CMAttachment *att = [self attachmentWithMimeType:@"image/png"
                                          ownerType:@"SIGNATURE"
                                           filename:@"sig.png"];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:nil];

    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
                               @"Upper-case 'SIGNATURE' ownerType must match case-insensitively");
}

- (void)testSignatureCaptured_MixedCaseOwnerType_MatchesCaseInsensitive {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    CMAttachment *att = [self attachmentWithMimeType:@"image/png"
                                          ownerType:@"Signature"
                                           filename:@"sig.png"];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:nil];

    XCTAssertEqualWithAccuracy([result[CMAutoScorerResultPointsKey] doubleValue], 1.0, 0.001,
                               @"Mixed-case 'Signature' ownerType must match case-insensitively");
}

- (void)testSignatureCaptured_WithSignature_EvidenceContainsAttachmentId {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];
    CMAttachment *att = [self attachmentWithMimeType:@"image/png"
                                          ownerType:@"signature"
                                           filename:@"sig.png"];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[att] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    XCTAssertTrue([evidence containsString:@"Signature attachment found"],
                  @"Positive signature evidence must mention 'Signature attachment found'");
}

- (void)testSignatureCaptured_NoSignature_EvidenceDescribesAbsence {
    CMOrder *order = [self deliveredOrderWithDropoffEnd:[NSDate date]
                                           deliveredAt:[NSDate date]];

    CMAutoScorer_SignatureCaptured *scorer = [[CMAutoScorer_SignatureCaptured alloc] init];
    NSDictionary *result = [scorer evaluateForOrder:order attachments:@[] error:nil];

    NSString *evidence = result[CMAutoScorerResultEvidenceKey];
    XCTAssertNotNil(evidence);
    XCTAssertTrue([evidence containsString:@"No signature"],
                  @"Absence evidence must mention 'No signature'");
}

@end
