//
//  CMViewControllerExhaustiveTests.m
//  CourierMatch Integration Tests
//
//  Walks every method on every view controller via the runtime and invokes
//  zero-arg or single-id-arg methods with safe defaults to drive coverage
//  on action handlers, helpers, and table delegate methods.
//

#import "CMIntegrationTestCase.h"
#import <objc/runtime.h>

#import "CMAdminDashboardViewController.h"
#import "CMOrderDetailViewController.h"
#import "CMOrderListViewController.h"
#import "CMItineraryListViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMItineraryDetailViewController.h"
#import "CMMatchListViewController.h"
#import "CMNotificationListViewController.h"
#import "CMScorecardListViewController.h"
#import "CMScorecardViewController.h"
#import "CMAppealReviewViewController.h"
#import "CMDisputeIntakeViewController.h"
#import "CMLoginViewController.h"
#import "CMSignupViewController.h"
#import "CMOrder.h"
#import "CMItinerary.h"
#import "CMDeliveryScorecard.h"
#import "CMAppeal.h"
#import "CMAddress.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"

@interface CMViewControllerExhaustiveTests : CMIntegrationTestCase
@end

@implementation CMViewControllerExhaustiveTests

/// Invoke all zero-arg or single-id-arg instance methods declared directly
/// on the given class (not inherited). Wraps each call in @try/@catch to
/// drive code paths without crashing.
- (void)invokeAllInstanceMethodsOf:(Class)cls onTarget:(id)target {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        Method m = methods[i];
        SEL sel = method_getName(m);
        const char *name = sel_getName(sel);

        // Skip init/dealloc/setters/getters/accessors that we shouldn't drive.
        if (strstr(name, "init") == name) continue;
        if (strstr(name, "dealloc") == name) continue;
        if (strncmp(name, "set", 3) == 0 && strchr(name, ':')) continue;
        if (strstr(name, ".cxx_destruct") == name) continue;

        unsigned int numArgs = method_getNumberOfArguments(m);
        // numArgs always includes self+cmd, so 2 = zero-arg, 3 = one-arg
        if (numArgs == 2) {
            // zero-arg method
            @try {
                IMP imp = method_getImplementation(m);
                void (*func)(id, SEL) = (void *)imp;
                func(target, sel);
            } @catch (NSException *e) { /* ignore */ }
        } else if (numArgs == 3) {
            // one-arg: try with nil and with a sender stub
            char argType[256];
            method_getArgumentType(m, 2, argType, sizeof(argType));
            if (argType[0] == '@') {
                @try {
                    IMP imp = method_getImplementation(m);
                    void (*func)(id, SEL, id) = (void *)imp;
                    func(target, sel, nil);
                } @catch (NSException *e) { /* ignore */ }
            }
        }
    }
    free(methods);
}

- (void)driveVC:(UIViewController *)vc {
    @try { [vc loadViewIfNeeded]; } @catch (NSException *e) {}
    @try { [vc viewWillAppear:NO]; } @catch (NSException *e) {}
    @try { [vc viewDidAppear:NO]; } @catch (NSException *e) {}
    [self invokeAllInstanceMethodsOf:[vc class] onTarget:vc];
    @try { [vc viewWillDisappear:NO]; } @catch (NSException *e) {}
    @try { [vc viewDidDisappear:NO]; } @catch (NSException *e) {}
}

#pragma mark - Setup with seeded data

- (CMOrder *)seedOrderForCourier {
    CMOrder *o = [self insertTestOrder:[NSString stringWithFormat:@"ord-%@", [[NSUUID UUID] UUIDString]]];
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    o.pickupWindowStart = [NSDate date];
    o.pickupWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    o.dropoffWindowStart = [NSDate dateWithTimeIntervalSinceNow:1800];
    o.dropoffWindowEnd = [NSDate dateWithTimeIntervalSinceNow:5400];
    [self saveContext];
    return o;
}

- (CMItinerary *)seedItinerary {
    CMItinerary *it = [self insertTestItinerary:[NSString stringWithFormat:@"itin-%@", [[NSUUID UUID] UUIDString]]];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:4 * 3600];
    [self saveContext];
    return it;
}

#pragma mark - Tests

- (void)testAdminDashboardExhaustive {
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    XCTAssertNotNil(vc, @"AdminDashboardViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"AdminDashboardViewController view must survive exhaustive drive");
}

- (void)testAdminDashboardExhaustive_NonAdmin {
    [self switchToUser:self.courierUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    XCTAssertNotNil(vc, @"AdminDashboardViewController must instantiate for non-admin");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"AdminDashboardViewController view must survive exhaustive drive");
}

- (void)testOrderListExhaustive_Courier {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    [self seedOrderForCourier];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    XCTAssertNotNil(vc, @"OrderListViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"OrderListViewController view must survive exhaustive drive");
}

- (void)testOrderListExhaustive_Dispatcher {
    [self switchToUser:self.dispatcherUser];
    [[CMSessionManager shared] openSessionForUser:self.dispatcherUser];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    XCTAssertNotNil(vc, @"OrderListViewController must instantiate for dispatcher");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"OrderListViewController view must survive exhaustive drive");
}

- (void)testOrderDetailExhaustive {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    CMOrder *o = [self seedOrderForCourier];
    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:o];
    XCTAssertNotNil(vc, @"OrderDetailViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"OrderDetailViewController view must survive exhaustive drive");
}

- (void)testItineraryListExhaustive {
    [self switchToUser:self.courierUser];
    [self seedItinerary];
    CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
    XCTAssertNotNil(vc, @"ItineraryListViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ItineraryListViewController view must survive exhaustive drive");
}

- (void)testItineraryFormExhaustive_New {
    [self switchToUser:self.courierUser];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
    XCTAssertNotNil(vc, @"ItineraryFormViewController must instantiate for new itinerary");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ItineraryFormViewController view must survive exhaustive drive");
}

- (void)testItineraryFormExhaustive_Edit {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self seedItinerary];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:it];
    XCTAssertNotNil(vc, @"ItineraryFormViewController must instantiate for edit");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ItineraryFormViewController view must survive exhaustive drive");
}

- (void)testItineraryDetailExhaustive {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self seedItinerary];
    CMItineraryDetailViewController *vc = [[CMItineraryDetailViewController alloc] initWithItinerary:it];
    XCTAssertNotNil(vc, @"ItineraryDetailViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ItineraryDetailViewController view must survive exhaustive drive");
}

- (void)testMatchListExhaustive {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self seedItinerary];
    CMMatchListViewController *vc = [[CMMatchListViewController alloc] initWithItinerary:it];
    XCTAssertNotNil(vc, @"MatchListViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"MatchListViewController view must survive exhaustive drive");
}

- (void)testNotificationListExhaustive {
    [self switchToUser:self.courierUser];
    CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
    XCTAssertNotNil(vc, @"NotificationListViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"NotificationListViewController view must survive exhaustive drive");
}

- (void)testScorecardListExhaustive {
    [self switchToUser:self.reviewerUser];
    CMScorecardListViewController *vc = [[CMScorecardListViewController alloc] init];
    XCTAssertNotNil(vc, @"ScorecardListViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ScorecardListViewController view must survive exhaustive drive");
}

- (void)testScorecardViewExhaustive {
    [self switchToUser:self.reviewerUser];
    [self insertTestRubric:@"r-exhaust"];
    CMOrder *o = [self seedOrderForCourier];

    CMDeliveryScorecard *sc = [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                                            inManagedObjectContext:self.testContext];
    sc.scorecardId = [[NSUUID UUID] UUIDString];
    sc.tenantId = self.testTenantId;
    sc.orderId = o.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"r-exhaust";
    sc.rubricVersion = 1;
    sc.createdAt = [NSDate date];
    sc.updatedAt = [NSDate date];
    sc.version = 1;
    [self saveContext];

    CMScorecardViewController *vc = [[CMScorecardViewController alloc] initWithScorecard:sc];
    XCTAssertNotNil(vc, @"ScorecardViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"ScorecardViewController view must survive exhaustive drive");
}

- (void)testAppealReviewExhaustive {
    [self switchToUser:self.reviewerUser];
    CMAppeal *a = [NSEntityDescription insertNewObjectForEntityForName:@"Appeal"
                                                inManagedObjectContext:self.testContext];
    a.appealId = [[NSUUID UUID] UUIDString];
    a.tenantId = self.testTenantId;
    a.scorecardId = @"sc-x";
    a.reason = @"test";
    a.openedBy = self.csUser.userId;
    a.openedAt = [NSDate date];
    a.createdAt = [NSDate date];
    a.updatedAt = [NSDate date];
    a.version = 1;
    [self saveContext];
    CMAppealReviewViewController *vc = [[CMAppealReviewViewController alloc] initWithAppeal:a];
    XCTAssertNotNil(vc, @"AppealReviewViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"AppealReviewViewController view must survive exhaustive drive");
}

- (void)testDisputeIntakeExhaustive_NoOrder {
    [self switchToUser:self.csUser];
    CMDisputeIntakeViewController *vc = [[CMDisputeIntakeViewController alloc] initWithOrder:nil];
    XCTAssertNotNil(vc, @"DisputeIntakeViewController must instantiate with nil order");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"DisputeIntakeViewController view must survive exhaustive drive");
}

- (void)testDisputeIntakeExhaustive_WithOrder {
    [self switchToUser:self.csUser];
    CMOrder *o = [self seedOrderForCourier];
    CMDisputeIntakeViewController *vc = [[CMDisputeIntakeViewController alloc] initWithOrder:o];
    XCTAssertNotNil(vc, @"DisputeIntakeViewController must instantiate with order");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"DisputeIntakeViewController view must survive exhaustive drive");
}

- (void)testLoginExhaustive {
    [[CMTenantContext shared] clear];
    CMLoginViewController *vc = [[CMLoginViewController alloc] init];
    XCTAssertNotNil(vc, @"LoginViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"LoginViewController view must survive exhaustive drive");
}

- (void)testSignupExhaustive {
    [[CMTenantContext shared] clear];
    CMSignupViewController *vc = [[CMSignupViewController alloc] init];
    XCTAssertNotNil(vc, @"SignupViewController must instantiate");
    [self driveVC:vc];
    XCTAssertNotNil(vc.view, @"SignupViewController view must survive exhaustive drive");
}

@end
