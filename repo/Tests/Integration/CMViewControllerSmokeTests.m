//
//  CMViewControllerSmokeTests.m
//  CourierMatch Integration Tests
//
//  Smoke tests that instantiate view controllers, force viewDidLoad,
//  and exercise basic table data source / delegate paths to drive
//  meaningful coverage on UI layer code.
//

#import "CMIntegrationTestCase.h"
#import "CMAdminDashboardViewController.h"
#import "CMAppealReviewViewController.h"
#import "CMAppeal.h"
#import "CMDisputeIntakeViewController.h"
#import "CMLoginViewController.h"
#import "CMSignupViewController.h"
#import "CMItineraryDetailViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMItineraryListViewController.h"
#import "CMItinerary.h"
#import "CMMatchListViewController.h"
#import "CMNotificationListViewController.h"
#import "CMOrderDetailViewController.h"
#import "CMOrderListViewController.h"
#import "CMOrder.h"
#import "CMScorecardListViewController.h"
#import "CMScorecardViewController.h"
#import "CMDeliveryScorecard.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"
#import "CMAddress.h"

@interface CMViewControllerSmokeTests : CMIntegrationTestCase
@end

@implementation CMViewControllerSmokeTests

/// Force a VC's view to load and lay out.
- (void)forceLoad:(UIViewController *)vc {
    XCTAssertNoThrow([vc loadViewIfNeeded]);
    XCTAssertNoThrow([vc viewDidLoad]);
    XCTAssertNoThrow([vc viewWillAppear:NO]);
    XCTAssertNoThrow([vc viewDidAppear:NO]);
    XCTAssertNoThrow([vc viewWillDisappear:NO]);
    XCTAssertNoThrow([vc viewDidDisappear:NO]);
}

#pragma mark - Admin Dashboard

- (void)testAdminDashboardLoadsAsAdmin {
    [self switchToUser:self.adminUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [self forceLoad:vc];
    XCTAssertNotNil(vc.view);
    // Exercise table data source if available
    if ([vc respondsToSelector:@selector(tableView)]) {
        UITableView *tv = [vc valueForKey:@"tableView"];
        if (tv && [vc conformsToProtocol:@protocol(UITableViewDataSource)]) {
            id<UITableViewDataSource> ds = (id<UITableViewDataSource>)vc;
            NSInteger sections = [ds respondsToSelector:@selector(numberOfSectionsInTableView:)] ?
                [ds numberOfSectionsInTableView:tv] : 1;
            for (NSInteger s = 0; s < sections; s++) {
                NSInteger rows = [ds tableView:tv numberOfRowsInSection:s];
                for (NSInteger r = 0; r < MIN(rows, 3); r++) {
                    NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
                    XCTAssertNoThrow([ds tableView:tv cellForRowAtIndexPath:ip]);
                }
            }
        }
    }
}

- (void)testAdminDashboardLoadsAsNonAdmin {
    [self switchToUser:self.courierUser];
    CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
    [self forceLoad:vc];
    XCTAssertNotNil(vc.view);
}

#pragma mark - Login / Signup

- (void)testLoginViewControllerLoads {
    CMLoginViewController *vc = [[CMLoginViewController alloc] init];
    [self forceLoad:vc];
    XCTAssertNotNil(vc.view);
}

- (void)testSignupViewControllerLoads {
    CMSignupViewController *vc = [[CMSignupViewController alloc] init];
    [self forceLoad:vc];
    XCTAssertNotNil(vc.view);
}

#pragma mark - Itinerary

- (void)testItineraryListLoads {
    [self switchToUser:self.courierUser];
    CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
    [self forceLoad:vc];
}

- (void)testItineraryFormNewLoads {
    [self switchToUser:self.courierUser];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
    [self forceLoad:vc];
}

- (void)testItineraryFormEditLoads {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-vc-test"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMItineraryFormViewController *vc = [[CMItineraryFormViewController alloc] initWithItinerary:it];
    [self forceLoad:vc];
}

- (void)testItineraryDetailLoads {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-detail-vc"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMItineraryDetailViewController *vc = [[CMItineraryDetailViewController alloc] initWithItinerary:it];
    [self forceLoad:vc];
}

#pragma mark - Match

- (void)testMatchListLoads {
    [self switchToUser:self.courierUser];
    CMItinerary *it = [self insertTestItinerary:@"itin-match-vc"];
    it.originAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    it.destinationAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMMatchListViewController *vc = [[CMMatchListViewController alloc] initWithItinerary:it];
    [self forceLoad:vc];
}

#pragma mark - Notifications

- (void)testNotificationListLoads {
    [self switchToUser:self.courierUser];
    CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
    [self forceLoad:vc];
}

#pragma mark - Orders

- (void)testOrderListLoads {
    [self switchToUser:self.courierUser];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    [self forceLoad:vc];
}

- (void)testOrderListLoadsAsDispatcher {
    [self switchToUser:self.dispatcherUser];
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    [self forceLoad:vc];
}

- (void)testOrderDetailLoads {
    [self switchToUser:self.courierUser];
    CMOrder *order = [self insertTestOrder:@"ord-vc-test"];
    order.assignedCourierId = self.courierUser.userId;
    order.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    order.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:order];
    [self forceLoad:vc];
}

- (void)testOrderDetailLoadsAsAdmin {
    [self switchToUser:self.adminUser];
    CMOrder *order = [self insertTestOrder:@"ord-vc-admin"];
    order.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    order.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMOrderDetailViewController *vc = [[CMOrderDetailViewController alloc] initWithOrder:order];
    [self forceLoad:vc];
}

#pragma mark - Scoring

- (void)testScorecardListLoads {
    [self switchToUser:self.reviewerUser];
    CMScorecardListViewController *vc = [[CMScorecardListViewController alloc] init];
    [self forceLoad:vc];
}

- (void)testScorecardViewControllerLoads {
    [self switchToUser:self.reviewerUser];
    [self insertTestRubric:@"rubric-vc-test"];
    CMOrder *order = [self insertTestOrder:@"ord-sc-vc"];
    order.status = CMOrderStatusDelivered;
    order.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    order.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];

    CMDeliveryScorecard *sc = [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                                            inManagedObjectContext:self.testContext];
    sc.scorecardId = [[NSUUID UUID] UUIDString];
    sc.tenantId = self.testTenantId;
    sc.orderId = order.orderId;
    sc.courierId = self.courierUser.userId;
    sc.rubricId = @"rubric-vc-test";
    sc.rubricVersion = 1;
    sc.createdAt = [NSDate date];
    sc.updatedAt = [NSDate date];
    sc.version = 1;
    [self saveContext];

    CMScorecardViewController *vc = [[CMScorecardViewController alloc] initWithScorecard:sc];
    [self forceLoad:vc];
}

#pragma mark - Appeals / Disputes

- (void)testDisputeIntakeWithoutOrderLoads {
    [self switchToUser:self.csUser];
    CMDisputeIntakeViewController *vc = [[CMDisputeIntakeViewController alloc] initWithOrder:nil];
    [self forceLoad:vc];
}

- (void)testDisputeIntakeWithOrderLoads {
    [self switchToUser:self.csUser];
    CMOrder *order = [self insertTestOrder:@"ord-dispute-vc"];
    order.pickupAddress = [self addressWithLat:40.0 lng:-74.0 zip:@"10001" city:@"NYC"];
    order.dropoffAddress = [self addressWithLat:40.1 lng:-74.1 zip:@"10002" city:@"NYC"];
    [self saveContext];
    CMDisputeIntakeViewController *vc = [[CMDisputeIntakeViewController alloc] initWithOrder:order];
    [self forceLoad:vc];
}

- (void)testAppealReviewLoads {
    [self switchToUser:self.reviewerUser];
    CMAppeal *appeal = [NSEntityDescription insertNewObjectForEntityForName:@"Appeal"
                                                     inManagedObjectContext:self.testContext];
    appeal.appealId = [[NSUUID UUID] UUIDString];
    appeal.tenantId = self.testTenantId;
    appeal.scorecardId = @"sc-test";
    appeal.reason = @"test reason";
    appeal.openedBy = self.csUser.userId;
    appeal.openedAt = [NSDate date];
    appeal.createdAt = [NSDate date];
    appeal.updatedAt = [NSDate date];
    appeal.version = 1;
    [self saveContext];
    CMAppealReviewViewController *vc = [[CMAppealReviewViewController alloc] initWithAppeal:appeal];
    [self forceLoad:vc];
}

@end
