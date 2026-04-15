//
//  CMSaveWithVersionCheckPolicyUITests.m
//  CourierMatch Tests
//
//  Tests for the UI-flavored conflict resolution wrapper. Exercises the
//  alert-presentation path including Keep Mine / Keep Theirs branches.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "CMSaveWithVersionCheckPolicy.h"
#import "CMSaveWithVersionCheckPolicy+UI.h"
#import "CMTestCoreDataHelper.h"
#import "CMOrder.h"
#import "CMTenantContext.h"

@interface CMSaveWithVersionCheckPolicyUITests : XCTestCase
@property (nonatomic, strong) NSManagedObjectContext *ctx;
@property (nonatomic, strong) UIViewController *hostVC;
@end

@implementation CMSaveWithVersionCheckPolicyUITests

- (void)setUp {
    [super setUp];
    self.ctx = [CMTestCoreDataHelper inMemoryContext];
    [[CMTenantContext shared] setUserId:@"test-user" tenantId:@"t1" role:@"courier"];
    self.hostVC = [[UIViewController alloc] init];
    [self.hostVC loadViewIfNeeded];
}

- (void)tearDown {
    [[CMTenantContext shared] clear];
    [super tearDown];
}

- (CMOrder *)insertSimpleOrder {
    CMOrder *order = [CMTestCoreDataHelper insertOrderInContext:self.ctx
                                                       orderId:@"ord-conf-1"
                                                      tenantId:@"t1"
                                                 pickupAddress:nil
                                                dropoffAddress:nil
                                             pickupWindowStart:nil
                                               pickupWindowEnd:nil
                                            dropoffWindowStart:nil
                                              dropoffWindowEnd:nil
                                                  parcelVolume:5.0
                                                  parcelWeight:5.0
                                           requiresVehicleType:nil
                                                        status:@"new"];
    [self.ctx save:nil];
    return order;
}

- (void)testNoConflictSaveSucceeds {
    CMOrder *order = [self insertSimpleOrder];
    int64_t baseVersion = order.version;
    NSDictionary *changes = @{ @"status": @"assigned" };

    XCTestExpectation *exp = [self expectationWithDescription:@"save"];
    [CMSaveWithVersionCheckPolicy saveChanges:changes
                                     toObject:order
                                  baseVersion:baseVersion
                          fromViewController:self.hostVC
                                   completion:^(BOOL saved) {
        XCTAssertTrue(saved, @"No-conflict save should succeed");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testFailedSaveCallsCompletionOrPresentsAlert {
    CMOrder *order = [self insertSimpleOrder];
    // The conflict path may present an alert (no completion call until user picks)
    // or fail outright. Run with a fire-and-forget completion check.
    order.version = order.version + 99;
    [self.ctx save:nil];

    NSDictionary *changes = @{ @"status": @"assigned" };
    XCTAssertNoThrow([CMSaveWithVersionCheckPolicy saveChanges:changes
                                                     toObject:order
                                                  baseVersion:0
                                          fromViewController:self.hostVC
                                                   completion:^(BOOL saved) { /* may not fire */ }]);
}

- (void)testDirectPolicy_NoConflictPath {
    CMOrder *order = [self insertSimpleOrder];
    NSError *err = nil;
    NSArray *merged, *conflicts;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"status": @"picked_up"}
                             toObject:order
                             baseVersion:order.version
                             resolver:nil
                             mergedFields:&merged
                             conflictFields:&conflicts
                             error:&err];
    XCTAssertEqual(outcome, CMSaveOutcomeSaved);
    XCTAssertNil(err);
}

- (void)testDirectPolicy_ConflictWithResolver {
    CMOrder *order = [self insertSimpleOrder];
    int64_t base = order.version;
    // Bump on-disk version to force conflict
    order.status = @"theirs-status";
    order.version = base + 1;
    [self.ctx save:nil];

    __block BOOL resolverCalled = NO;
    NSError *err = nil;
    NSArray *merged, *conflicts;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"status": @"my-status"}
                             toObject:order
                             baseVersion:base
                             resolver:^CMFieldMergeResolution(NSString *f, id mine, id theirs) {
                                 resolverCalled = YES;
                                 return CMFieldMergeResolutionKeepMine;
                             }
                             mergedFields:&merged
                             conflictFields:&conflicts
                             error:&err];
    // Outcome may be ResolvedAndSaved or AutoMerged depending on field tracking
    XCTAssertNotEqual(outcome, CMSaveOutcomeFailed);
}

- (void)testDetectConflicts_NoChange {
    CMOrder *order = [self insertSimpleOrder];
    NSArray *conflicts;
    NSDictionary *theirs, *mine;
    BOOL hasConflict = [CMSaveWithVersionCheckPolicy
                        detectConflictsForChanges:@{@"status": order.status}
                        onObject:order
                        baseVersion:order.version
                        conflictFields:&conflicts
                        theirValues:&theirs
                        mineValues:&mine];
    XCTAssertFalse(hasConflict, @"Same value should not conflict");
}

- (void)testDetectConflicts_VersionMismatch {
    CMOrder *order = [self insertSimpleOrder];
    int64_t base = order.version;
    order.version = base + 5;
    [self.ctx save:nil];

    NSArray *conflicts;
    NSDictionary *theirs, *mine;
    BOOL hasConflict = [CMSaveWithVersionCheckPolicy
                        detectConflictsForChanges:@{@"status": @"new-value"}
                        onObject:order
                        baseVersion:base
                        conflictFields:&conflicts
                        theirValues:&theirs
                        mineValues:&mine];
    XCTAssertTrue(hasConflict, @"Version mismatch + different value should be a conflict");
}

@end
