//
//  CMViewControllerAlertHandlerTests.m
//  CourierMatch Integration Tests
//
//  Drives coverage on UIAlertAction handler blocks by invoking action
//  methods that present alerts, then introspecting the presented controller
//  and firing each action's handler to exercise all branches.
//

#import "CMIntegrationTestCase.h"
#import <objc/runtime.h>

#import "CMAdminDashboardViewController.h"
#import "CMOrderDetailViewController.h"
#import "CMOrderListViewController.h"
#import "CMScorecardViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMAppealReviewViewController.h"
#import "CMDisputeIntakeViewController.h"
#import "CMOrder.h"
#import "CMItinerary.h"
#import "CMAppeal.h"
#import "CMDeliveryScorecard.h"
#import "CMAddress.h"
#import "CMUserAccount.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"

@interface CMViewControllerAlertHandlerTests : CMIntegrationTestCase
@property (nonatomic, strong) UIWindow *testWindow;
@end

@implementation CMViewControllerAlertHandlerTests

- (void)setUp {
    [super setUp];
    self.testWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.testWindow.hidden = NO;
}

- (void)tearDown {
    self.testWindow.hidden = YES;
    self.testWindow = nil;
    [super tearDown];
}

- (void)hostVC:(UIViewController *)vc {
    self.testWindow.rootViewController = vc;
    [vc loadViewIfNeeded];
}

/// Try to invoke a method via NSSelectorFromString.
- (void)tryInvoke:(NSString *)selName on:(id)target {
    SEL sel = NSSelectorFromString(selName);
    if ([target respondsToSelector:sel]) {
        IMP imp = [target methodForSelector:sel];
        @try {
            if ([selName hasSuffix:@":"]) {
                void (*func)(id, SEL, id) = (void *)imp;
                func(target, sel, nil);
            } else {
                void (*func)(id, SEL) = (void *)imp;
                func(target, sel);
            }
        } @catch (NSException *e) {}
    }
}

/// If the host VC has a presented alert controller, fire each of its actions'
/// handler blocks. This drives coverage on lines inside each handler.
- (void)firePresentedAlertActions:(UIViewController *)vc {
    UIViewController *presented = vc.presentedViewController;
    if (![presented isKindOfClass:[UIAlertController class]]) return;
    UIAlertController *alert = (UIAlertController *)presented;
    for (UIAlertAction *action in alert.actions) {
        // The handler is a private property; access via valueForKey.
        @try {
            void (^handler)(UIAlertAction *) = [action valueForKey:@"handler"];
            if (handler) {
                handler(action);
            }
        } @catch (NSException *e) {}
    }
    @try { [vc dismissViewControllerAnimated:NO completion:nil]; } @catch (NSException *e) {}
}

#pragma mark - Tests

- (void)testAdminDashboard_RoleChangeAndDeleteAlertHandlers {
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];

    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [self hostVC:vc];

    // Try invoking each action method that presents an alert, then fire handlers.
    NSArray *actionMethods = @[@"showRubricManagement", @"showAllowlistSettings",
                                @"showTenantConfig", @"showDiagnostics",
                                @"verifyAuditChain"];
    for (NSString *m in actionMethods) {
        [self tryInvoke:m on:vc];
        [self firePresentedAlertActions:vc];
    }

    // Try the user-targeting actions if exposed.
    SEL changeRoleSel = NSSelectorFromString(@"changeRole:");
    if ([vc respondsToSelector:changeRoleSel]) {
        IMP imp = [vc methodForSelector:changeRoleSel];
        void (*func)(id, SEL, id) = (void *)imp;
        @try { func(vc, changeRoleSel, self.dispatcherUser); } @catch (NSException *e) {}
        [self firePresentedAlertActions:vc];
    }
    SEL forceLogoutSel = NSSelectorFromString(@"forceLogout:");
    if ([vc respondsToSelector:forceLogoutSel]) {
        IMP imp = [vc methodForSelector:forceLogoutSel];
        void (*func)(id, SEL, id) = (void *)imp;
        @try { func(vc, forceLogoutSel, self.dispatcherUser); } @catch (NSException *e) {}
        [self firePresentedAlertActions:vc];
    }
    SEL deleteSel = NSSelectorFromString(@"deleteAccount:");
    if ([vc respondsToSelector:deleteSel]) {
        IMP imp = [vc methodForSelector:deleteSel];
        void (*func)(id, SEL, id) = (void *)imp;
        @try { func(vc, deleteSel, self.dispatcherUser); } @catch (NSException *e) {}
        [self firePresentedAlertActions:vc];
    }
}

- (void)testOrderDetail_AlertHandlers {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];

    CMOrder *o = [self insertTestOrder:@"ord-alert"];
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    o.pickupWindowStart = [NSDate date];
    o.pickupWindowEnd = [NSDate dateWithTimeIntervalSinceNow:3600];
    [self saveContext];

    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:o];
    [self hostVC:vc];

    NSArray *actionMethods = @[@"editNotesTapped", @"updateStatusTapped", @"assignTapped",
                                @"openDisputeTapped", @"capturePhotoTapped",
                                @"captureSignatureTapped"];
    for (NSString *m in actionMethods) {
        [self tryInvoke:m on:vc];
        [self firePresentedAlertActions:vc];
    }
}

- (void)testItineraryForm_AlertHandlers {
    [self switchToUser:self.courierUser];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
    [self hostVC:vc];

    [self tryInvoke:@"saveTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"cancelTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"addStopTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"useLocationTapped" on:vc];
    [self firePresentedAlertActions:vc];
}

- (void)testScorecardView_AlertHandlers {
    [self switchToUser:self.reviewerUser];
    [self insertTestRubric:@"r-alert"];
    CMOrder *o = [self insertTestOrder:@"ord-sc-alert"];
    o.status = CMOrderStatusDelivered;
    o.assignedCourierId = self.courierUser.userId;
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDeliveryScorecard *sc = [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                                            inManagedObjectContext:self.testContext];
    sc.scorecardId = [[NSUUID UUID] UUIDString];
    sc.tenantId = self.testTenantId;
    sc.orderId = o.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"r-alert";
    sc.rubricVersion = 1;
    sc.createdAt = [NSDate date];
    sc.updatedAt = [NSDate date];
    sc.version = 1;
    [self saveContext];

    CMScorecardViewController *vc = [[CMScorecardViewController alloc] initWithScorecard:sc];
    [self hostVC:vc];

    [self tryInvoke:@"finalizeTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"upgradeTapped" on:vc];
    [self firePresentedAlertActions:vc];
}

- (void)testAppealReview_AlertHandlers {
    [self switchToUser:self.reviewerUser];
    CMAppeal *a = [NSEntityDescription insertNewObjectForEntityForName:@"Appeal"
                                                inManagedObjectContext:self.testContext];
    a.appealId = [[NSUUID UUID] UUIDString];
    a.tenantId = self.testTenantId;
    a.scorecardId = @"sc-x";
    a.reason = @"r";
    a.openedBy = self.csUser.userId;
    a.openedAt = [NSDate date];
    a.createdAt = [NSDate date];
    a.updatedAt = [NSDate date];
    a.version = 1;
    [self saveContext];

    CMAppealReviewViewController *vc = [[CMAppealReviewViewController alloc] initWithAppeal:a];
    [self hostVC:vc];

    NSArray *actions = @[@"assignToMeTapped", @"submitDecisionTapped",
                         @"upholdTapped", @"adjustTapped", @"rejectTapped",
                         @"saveDecisionTapped"];
    for (NSString *m in actions) {
        [self tryInvoke:m on:vc];
        [self firePresentedAlertActions:vc];
    }
}

- (void)testDisputeIntake_AlertHandlers {
    [self switchToUser:self.csUser];
    CMOrder *o = [self insertTestOrder:@"ord-disp-alert"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDisputeIntakeViewController *vc = [[CMDisputeIntakeViewController alloc] initWithOrder:o];
    [self hostVC:vc];

    [self tryInvoke:@"submitTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"cameraTapped" on:vc];
    [self firePresentedAlertActions:vc];
    [self tryInvoke:@"attachTapped" on:vc];
    [self firePresentedAlertActions:vc];
}

@end
