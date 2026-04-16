//
//  CMViewControllerStateTests.m
//  CourierMatch Integration Tests
//
//  Strict behavioral contract tests for UIViewControllers:
//  - title set correctly in viewDidLoad
//  - protocol conformances declared (UITableViewDataSource, etc.)
//  - UITableView present in view hierarchy for list VCs
//  - UITextField present in auth VCs
//  - table data source returns correct row count with seeded data
//

#import "CMIntegrationTestCase.h"
#import "CMOrderListViewController.h"
#import "CMOrderDetailViewController.h"
#import "CMItineraryListViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMItineraryDetailViewController.h"
#import "CMNotificationListViewController.h"
#import "CMAdminDashboardViewController.h"
#import "CMScorecardListViewController.h"
#import "CMScorecardViewController.h"
#import "CMLoginViewController.h"
#import "CMSignupViewController.h"
#import "CMAppealReviewViewController.h"
#import "CMDisputeIntakeViewController.h"
#import "CMMatchListViewController.h"
#import "CMOrder.h"
#import "CMItinerary.h"
#import "CMAppeal.h"
#import "CMDeliveryScorecard.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"
#import "CMAddress.h"
#import "CMTheme.h"

@interface CMViewControllerStateTests : CMIntegrationTestCase
@end

@implementation CMViewControllerStateTests

#pragma mark - Helpers

- (UITableView *)firstTableViewIn:(UIView *)view {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) {
        UITableView *t = [self firstTableViewIn:sub];
        if (t) return t;
    }
    return nil;
}

- (UITextField *)firstTextFieldIn:(UIView *)view {
    if ([view isKindOfClass:[UITextField class]]) return (UITextField *)view;
    for (UIView *sub in view.subviews) {
        UITextField *t = [self firstTextFieldIn:sub];
        if (t) return t;
    }
    return nil;
}

- (NSInteger)totalRowsInTableView:(UITableView *)tv {
    if (!tv || !tv.dataSource) return 0;
    NSInteger sections = [tv.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]
        ? [tv.dataSource numberOfSectionsInTableView:tv] : 1;
    NSInteger total = 0;
    for (NSInteger s = 0; s < sections; s++) {
        total += [tv.dataSource tableView:tv numberOfRowsInSection:s];
    }
    return total;
}

#pragma mark - CMOrderListViewController

- (void)testOrderListViewController_Title_IsOrders {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Orders",
                          @"CMOrderListViewController must set title to 'Orders' in viewDidLoad");
}

- (void)testOrderListViewController_ConformsToUITableViewDataSource {
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMOrderListViewController must conform to UITableViewDataSource");
}

- (void)testOrderListViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMOrderListViewController view hierarchy must contain a UITableView");
}

- (void)testOrderListViewController_WithSeededOrders_TableHasRows {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];

    for (int i = 0; i < 2; i++) {
        CMOrder *o = [self insertTestOrder:[NSString stringWithFormat:@"ord-state-%d", i]];
        o.assignedCourierId = self.courierUser.userId;
        o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
        o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    }
    [self saveContext];

    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    [vc loadViewIfNeeded];
    [vc viewWillAppear:NO];  // triggers data fetch

    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"Table view must exist after viewWillAppear:");
    NSInteger rows = [self totalRowsInTableView:tv];
    XCTAssertGreaterThanOrEqual(rows, 1,
                                @"After seeding orders for the current user, the table must show at least 1 row");
}

#pragma mark - CMOrderDetailViewController

- (void)testOrderDetailViewController_Title_IsOrderDetail {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    CMOrder *o = [self insertTestOrder:@"ord-detail-st"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:o];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Order Detail",
                          @"CMOrderDetailViewController must set title to 'Order Detail' in viewDidLoad");
}

- (void)testOrderDetailViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    CMOrder *o = [self insertTestOrder:@"ord-detail-tv"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:o];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMOrderDetailViewController view hierarchy must contain a UITableView");
}

#pragma mark - CMItineraryListViewController

- (void)testItineraryListViewController_Title_IsMyItineraries {
    [self switchToUser:self.courierUser];
    CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"My Itineraries",
                          @"CMItineraryListViewController must set title to 'My Itineraries' in viewDidLoad");
}

- (void)testItineraryListViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMItineraryListViewController view hierarchy must contain a UITableView");
}

- (void)testItineraryListViewController_ConformsToUITableViewDataSource {
    CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMItineraryListViewController must conform to UITableViewDataSource");
}

#pragma mark - CMNotificationListViewController

- (void)testNotificationListViewController_Title_IsNotifications {
    [self switchToUser:self.courierUser];
    CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Notifications",
                          @"CMNotificationListViewController must set title to 'Notifications' in viewDidLoad");
}

- (void)testNotificationListViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMNotificationListViewController view hierarchy must contain a UITableView");
}

- (void)testNotificationListViewController_ConformsToUITableViewDataSource {
    CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMNotificationListViewController must conform to UITableViewDataSource");
}

#pragma mark - CMAdminDashboardViewController

- (void)testAdminDashboardViewController_Title_IsAdminDashboard {
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Admin Dashboard",
                          @"CMAdminDashboardViewController must set title to 'Admin Dashboard' in viewDidLoad");
}

- (void)testAdminDashboardViewController_ConformsToUITableViewDataSource {
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMAdminDashboardViewController must conform to UITableViewDataSource");
}

- (void)testAdminDashboardViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMAdminDashboardViewController view hierarchy must contain a UITableView");
}

- (void)testAdminDashboardViewController_TableHasSections {
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv);
    if ([tv.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
        NSInteger sections = [tv.dataSource numberOfSectionsInTableView:tv];
        XCTAssertGreaterThan(sections, 0,
                             @"CMAdminDashboardViewController table must have at least one section");
    }
}

#pragma mark - CMScorecardListViewController

- (void)testScorecardListViewController_Title_IsScoring {
    [self switchToUser:self.reviewerUser];
    CMScorecardListViewController *vc = [[CMScorecardListViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Scoring",
                          @"CMScorecardListViewController must set title to 'Scoring' in viewDidLoad");
}

- (void)testScorecardListViewController_ConformsToUITableViewDataSource {
    CMScorecardListViewController *vc = [[CMScorecardListViewController alloc] init];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMScorecardListViewController must conform to UITableViewDataSource");
}

- (void)testScorecardListViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.reviewerUser];
    CMScorecardListViewController *vc = [[CMScorecardListViewController alloc] init];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv, @"CMScorecardListViewController view hierarchy must contain a UITableView");
}

#pragma mark - CMLoginViewController

- (void)testLoginViewController_HasTextFieldSubviewsAfterViewDidLoad {
    [[CMTenantContext shared] clear];
    CMLoginViewController *vc = [[CMLoginViewController alloc] init];
    [vc loadViewIfNeeded];
    UITextField *tf = [self firstTextFieldIn:vc.view];
    XCTAssertNotNil(tf,
                    @"CMLoginViewController must create UITextField subviews in viewDidLoad "
                     "(at minimum: username and password fields)");
}

- (void)testLoginViewController_BackgroundColor_IsSystemBackground {
    [[CMTenantContext shared] clear];
    CMLoginViewController *vc = [[CMLoginViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.view.backgroundColor, [UIColor systemBackgroundColor],
                          @"CMLoginViewController root view background must be systemBackgroundColor");
}

- (void)testLoginViewController_IsKindOfUIViewController {
    CMLoginViewController *vc = [[CMLoginViewController alloc] init];
    XCTAssertTrue([vc isKindOfClass:[UIViewController class]],
                  @"CMLoginViewController must be a UIViewController subclass");
}

#pragma mark - CMSignupViewController

- (void)testSignupViewController_Title_IsCreateAccount {
    [[CMTenantContext shared] clear];
    CMSignupViewController *vc = [[CMSignupViewController alloc] init];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Create Account",
                          @"CMSignupViewController must set title to 'Create Account' in viewDidLoad");
}

- (void)testSignupViewController_HasTextFieldSubviewsAfterViewDidLoad {
    [[CMTenantContext shared] clear];
    CMSignupViewController *vc = [[CMSignupViewController alloc] init];
    [vc loadViewIfNeeded];
    UITextField *tf = [self firstTextFieldIn:vc.view];
    XCTAssertNotNil(tf,
                    @"CMSignupViewController must create UITextField subviews in viewDidLoad "
                     "(at minimum: tenant/username/password fields)");
}

#pragma mark - CMItineraryFormViewController

- (void)testItineraryFormViewController_NewMode_Title_IsNewItinerary {
    [self switchToUser:self.courierUser];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"New Itinerary",
                          @"CMItineraryFormViewController in new mode must set title to 'New Itinerary'");
}

- (void)testItineraryFormViewController_EditMode_Title_IsEditItinerary {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-edit-state"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:4 * 3600];
    [self saveContext];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:it];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Edit Itinerary",
                          @"CMItineraryFormViewController in edit mode must set title to 'Edit Itinerary'");
}

- (void)testItineraryFormViewController_HasTextFieldSubviewsAfterViewDidLoad {
    [self switchToUser:self.courierUser];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
    [vc loadViewIfNeeded];
    UITextField *tf = [self firstTextFieldIn:vc.view];
    XCTAssertNotNil(tf,
                    @"CMItineraryFormViewController must create UITextField subviews in viewDidLoad "
                     "(at minimum: origin/destination address fields)");
}

#pragma mark - CMItineraryDetailViewController

- (void)testItineraryDetailViewController_Title_IsItineraryDetails {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-detail-state"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:4 * 3600];
    [self saveContext];
    CMItineraryDetailViewController *vc =
        [[CMItineraryDetailViewController alloc] initWithItinerary:it];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Itinerary Details",
                          @"CMItineraryDetailViewController must set title to 'Itinerary Details' in viewDidLoad");
}

- (void)testItineraryDetailViewController_ConformsToUITableViewDataSource {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-detail-ds"];
    [self saveContext];
    CMItineraryDetailViewController *vc =
        [[CMItineraryDetailViewController alloc] initWithItinerary:it];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMItineraryDetailViewController must conform to UITableViewDataSource");
}

- (void)testItineraryDetailViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-detail-tv"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMItineraryDetailViewController *vc =
        [[CMItineraryDetailViewController alloc] initWithItinerary:it];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv,
                    @"CMItineraryDetailViewController view hierarchy must contain a UITableView");
}

#pragma mark - CMScorecardViewController

- (void)testScorecardViewController_Title_IsScorecard {
    [self switchToUser:self.reviewerUser];
    [self insertTestRubric:@"r-state"];
    CMOrder *o = [self insertTestOrder:@"ord-sc-state"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMDeliveryScorecard *sc =
        [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                      inManagedObjectContext:self.testContext];
    sc.scorecardId = [[NSUUID UUID] UUIDString];
    sc.tenantId = self.testTenantId;
    sc.orderId = o.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"r-state";
    sc.rubricVersion = 1;
    sc.createdAt = [NSDate date];
    sc.updatedAt = [NSDate date];
    sc.version = 1;
    [self saveContext];
    CMScorecardViewController *vc =
        [[CMScorecardViewController alloc] initWithScorecard:sc];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Scorecard",
                          @"CMScorecardViewController must set title to 'Scorecard' in viewDidLoad");
}

- (void)testScorecardViewController_ConformsToUITableViewDataSource {
    [self switchToUser:self.reviewerUser];
    CMDeliveryScorecard *sc =
        [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                      inManagedObjectContext:self.testContext];
    sc.scorecardId = [[NSUUID UUID] UUIDString];
    sc.tenantId = self.testTenantId;
    sc.rubricId = @"r-state-ds";
    sc.rubricVersion = 1;
    sc.courierId = @"courier-state-ds";
    sc.orderId = @"order-state-ds";
    sc.createdAt = [NSDate date];
    sc.updatedAt = [NSDate date];
    sc.version = 1;
    [self saveContext];
    CMScorecardViewController *vc =
        [[CMScorecardViewController alloc] initWithScorecard:sc];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMScorecardViewController must conform to UITableViewDataSource");
}

#pragma mark - CMAppealReviewViewController

- (void)testAppealReviewViewController_Title_IsAppealReview {
    [self switchToUser:self.reviewerUser];
    CMAppeal *a = [NSEntityDescription insertNewObjectForEntityForName:@"Appeal"
                                                inManagedObjectContext:self.testContext];
    a.appealId = [[NSUUID UUID] UUIDString];
    a.tenantId = self.testTenantId;
    a.scorecardId = @"sc-state";
    a.reason = @"state test";
    a.openedBy = self.csUser.userId;
    a.openedAt = [NSDate date];
    a.createdAt = [NSDate date];
    a.updatedAt = [NSDate date];
    a.version = 1;
    [self saveContext];
    CMAppealReviewViewController *vc =
        [[CMAppealReviewViewController alloc] initWithAppeal:a];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Appeal Review",
                          @"CMAppealReviewViewController must set title to 'Appeal Review' in viewDidLoad");
}

- (void)testAppealReviewViewController_ConformsToUITableViewDataSource {
    [self switchToUser:self.reviewerUser];
    CMAppeal *a = [NSEntityDescription insertNewObjectForEntityForName:@"Appeal"
                                                inManagedObjectContext:self.testContext];
    a.appealId = [[NSUUID UUID] UUIDString];
    a.tenantId = self.testTenantId;
    a.scorecardId = @"sc-state-ds";
    a.reason = @"r";
    a.openedBy = self.csUser.userId;
    a.openedAt = [NSDate date];
    a.createdAt = [NSDate date];
    a.updatedAt = [NSDate date];
    a.version = 1;
    [self saveContext];
    CMAppealReviewViewController *vc =
        [[CMAppealReviewViewController alloc] initWithAppeal:a];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMAppealReviewViewController must conform to UITableViewDataSource");
}

#pragma mark - CMDisputeIntakeViewController

- (void)testDisputeIntakeViewController_Title_IsOpenDispute {
    [self switchToUser:self.csUser];
    CMOrder *o = [self insertTestOrder:@"ord-disp-state"];
    o.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    o.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMDisputeIntakeViewController *vc =
        [[CMDisputeIntakeViewController alloc] initWithOrder:o];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Open Dispute",
                          @"CMDisputeIntakeViewController must set title to 'Open Dispute' in viewDidLoad");
}

- (void)testDisputeIntakeViewController_HasTextFieldSubviewsAfterViewDidLoad {
    [self switchToUser:self.csUser];
    CMDisputeIntakeViewController *vc =
        [[CMDisputeIntakeViewController alloc] initWithOrder:nil];
    [vc loadViewIfNeeded];
    UITextField *tf = [self firstTextFieldIn:vc.view];
    XCTAssertNotNil(tf,
                    @"CMDisputeIntakeViewController must create UITextField subviews in viewDidLoad");
}

#pragma mark - CMMatchListViewController

- (void)testMatchListViewController_Title_IsMatchCandidates {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-match-state"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:4 * 3600];
    [self saveContext];
    CMMatchListViewController *vc =
        [[CMMatchListViewController alloc] initWithItinerary:it];
    [vc loadViewIfNeeded];
    XCTAssertEqualObjects(vc.title, @"Match Candidates",
                          @"CMMatchListViewController must set title to 'Match Candidates' in viewDidLoad");
}

- (void)testMatchListViewController_ConformsToUITableViewDataSource {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-match-ds"];
    [self saveContext];
    CMMatchListViewController *vc =
        [[CMMatchListViewController alloc] initWithItinerary:it];
    XCTAssertTrue([vc conformsToProtocol:@protocol(UITableViewDataSource)],
                  @"CMMatchListViewController must conform to UITableViewDataSource");
}

- (void)testMatchListViewController_HasTableViewInViewHierarchy {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-match-tv"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    it.departureWindowStart = [NSDate date];
    it.departureWindowEnd = [NSDate dateWithTimeIntervalSinceNow:4 * 3600];
    [self saveContext];
    CMMatchListViewController *vc =
        [[CMMatchListViewController alloc] initWithItinerary:it];
    [vc loadViewIfNeeded];
    UITableView *tv = [self firstTableViewIn:vc.view];
    XCTAssertNotNil(tv,
                    @"CMMatchListViewController view hierarchy must contain a UITableView");
}

@end
