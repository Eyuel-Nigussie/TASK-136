//
//  CMSceneDelegateTests.m
//  CourierMatch Integration Tests
//
//  Exercises SceneDelegate helper methods that build view controllers,
//  the sidebar, and notification/session handler code paths.
//  Uses the Objective-C runtime to call private methods directly since
//  SceneDelegate doesn't expose a public API beyond UIWindowSceneDelegate.
//

#import "CMIntegrationTestCase.h"
#import "SceneDelegate.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"

// Private method forwarding — avoids -Wundeclared-selector warnings while
// still exercising real code paths.
@interface SceneDelegate (TestForwardDeclarations)
- (NSArray *)buildTabViewControllers;
- (UIViewController *)buildSidebarViewController;
- (UIViewController *)viewControllerForSidebarItem:(NSString *)title;
- (UIViewController *)scoringPlaceholderViewController;
- (UIViewController *)buildOrderListViewController;
- (UIViewController *)buildItineraryDetailViewController;
- (UIViewController *)buildTabBarController;
- (void)handleSessionExpired:(NSNotification *)notification;
- (void)handleForceLogout:(NSNotification *)notification;
- (void)handleSessionOpened:(NSNotification *)notification;
- (void)handleLoginSuccess:(NSNotification *)notification;
- (void)handleCoreDataReady:(NSNotification *)notification;
- (void)registerSessionNotifications;
- (void)activityDetected:(UIGestureRecognizer *)recognizer;
@end

@interface CMSceneDelegateTests : CMIntegrationTestCase
@property (nonatomic, strong) SceneDelegate *sceneDelegate;
@end

@implementation CMSceneDelegateTests

- (void)setUp {
    [super setUp];
    self.sceneDelegate = [[SceneDelegate alloc] init];
    // Provide a UIWindow so methods that reference self.window don't crash.
    UIWindow *win = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 812)];
    self.sceneDelegate.window = win;
}

#pragma mark - Tab View Controllers (all roles)

- (void)testBuildTabViewControllers_CourierRole {
    [self switchToUser:self.courierUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    XCTAssertNotNil(tabs, @"buildTabViewControllers should return an array");
    XCTAssertGreaterThanOrEqual(tabs.count, 3u,
                                @"All roles get at least 3 tabs: Itineraries, Orders, Notifications");
    // Courier should NOT get Scoring or Admin tabs.
    XCTAssertEqual(tabs.count, 3u, @"Courier role should have exactly 3 tabs");
}

- (void)testBuildTabViewControllers_ReviewerRole {
    [self switchToUser:self.reviewerUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    // Reviewer gets Scoring tab too.
    XCTAssertEqual(tabs.count, 4u, @"Reviewer role should have 4 tabs (+ Scoring)");
}

- (void)testBuildTabViewControllers_FinanceRole {
    [self switchToUser:self.financeUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    XCTAssertEqual(tabs.count, 4u, @"Finance role should have 4 tabs (+ Scoring)");
}

- (void)testBuildTabViewControllers_AdminRole {
    [self switchToUser:self.adminUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    // Admin gets Scoring + Admin tabs.
    XCTAssertEqual(tabs.count, 5u, @"Admin role should have 5 tabs (+ Scoring + Admin)");
}

- (void)testBuildTabViewControllers_DispatcherRole {
    [self switchToUser:self.dispatcherUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    XCTAssertEqual(tabs.count, 3u, @"Dispatcher role should have 3 tabs");
}

- (void)testBuildTabViewControllers_CSRole {
    [self switchToUser:self.csUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    XCTAssertEqual(tabs.count, 3u, @"CS role should have 3 tabs");
}

- (void)testBuildTabViewControllers_EachTabIsNavigationController {
    [self switchToUser:self.courierUser];
    NSArray *tabs = [self.sceneDelegate buildTabViewControllers];
    for (UIViewController *tab in tabs) {
        XCTAssertTrue([tab isKindOfClass:[UINavigationController class]],
                      @"Each tab should be a UINavigationController");
    }
}

#pragma mark - Tab Bar Controller

- (void)testBuildTabBarControllerIsNotNil {
    [self switchToUser:self.courierUser];
    UITabBarController *tbc = [self.sceneDelegate buildTabBarController];
    XCTAssertNotNil(tbc);
    XCTAssertGreaterThan(tbc.viewControllers.count, 0u);
}

#pragma mark - Scoring Placeholder

- (void)testScoringPlaceholderViewControllerIsNotNil {
    UIViewController *vc = [self.sceneDelegate scoringPlaceholderViewController];
    XCTAssertNotNil(vc);
}

#pragma mark - Sidebar

- (void)testBuildSidebarViewController_AdminRole {
    [self switchToUser:self.adminUser];
    UIViewController *sidebar = [self.sceneDelegate buildSidebarViewController];
    XCTAssertNotNil(sidebar, @"Sidebar should be built for admin");
    XCTAssertEqualObjects(sidebar.title, @"CourierMatch");
}

- (void)testBuildSidebarViewController_CourierRole {
    [self switchToUser:self.courierUser];
    UIViewController *sidebar = [self.sceneDelegate buildSidebarViewController];
    XCTAssertNotNil(sidebar);
}

- (void)testBuildSidebarViewController_ReviewerRole {
    [self switchToUser:self.reviewerUser];
    UIViewController *sidebar = [self.sceneDelegate buildSidebarViewController];
    XCTAssertNotNil(sidebar);
}

#pragma mark - viewControllerForSidebarItem:

- (void)testViewControllerForSidebarItem_Itineraries {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Itineraries"];
    XCTAssertNotNil(vc, @"Itineraries sidebar item should return a VC");
}

- (void)testViewControllerForSidebarItem_Orders {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Orders"];
    XCTAssertNotNil(vc);
}

- (void)testViewControllerForSidebarItem_Notifications {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Notifications"];
    XCTAssertNotNil(vc);
}

- (void)testViewControllerForSidebarItem_Scoring {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Scoring"];
    XCTAssertNotNil(vc);
}

- (void)testViewControllerForSidebarItem_Admin {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Admin"];
    XCTAssertNotNil(vc);
}

- (void)testViewControllerForSidebarItem_Unknown {
    UIViewController *vc = [self.sceneDelegate viewControllerForSidebarItem:@"Unknown"];
    XCTAssertNil(vc, @"Unknown sidebar item should return nil");
}

#pragma mark - Helper Builders

- (void)testBuildOrderListViewControllerIsNotNil {
    UIViewController *vc = [self.sceneDelegate buildOrderListViewController];
    XCTAssertNotNil(vc);
    XCTAssertTrue([vc isKindOfClass:[UINavigationController class]]);
}

- (void)testBuildItineraryDetailViewControllerIsNotNil {
    UIViewController *vc = [self.sceneDelegate buildItineraryDetailViewController];
    XCTAssertNotNil(vc);
    XCTAssertTrue([vc isKindOfClass:[UINavigationController class]]);
}

#pragma mark - Session Notification Handlers

- (void)testHandleSessionExpired_SetsLoginRootController {
    // transitionToLoginWithMessage: dispatches the root-VC swap on the main queue.
    // Enqueue a follow-up block so we wait until the swap has run.
    NSNotification *n = [NSNotification notificationWithName:@"CMSessionDidExpireNotification"
                                                      object:nil];
    [self.sceneDelegate handleSessionExpired:n];

    XCTestExpectation *settled = [self expectationWithDescription:@"main-queue settled"];
    dispatch_async(dispatch_get_main_queue(), ^{ [settled fulfill]; });
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertTrue(
        [self.sceneDelegate.window.rootViewController
            isKindOfClass:NSClassFromString(@"CMLoginViewController")],
        @"handleSessionExpired must transition root to CMLoginViewController");
}

- (void)testHandleForceLogout_SetsLoginRootController {
    NSNotification *n = [NSNotification notificationWithName:@"CMSessionDidForceLogoutNotification"
                                                      object:nil];
    [self.sceneDelegate handleForceLogout:n];

    XCTestExpectation *settled = [self expectationWithDescription:@"main-queue settled"];
    dispatch_async(dispatch_get_main_queue(), ^{ [settled fulfill]; });
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertTrue(
        [self.sceneDelegate.window.rootViewController
            isKindOfClass:NSClassFromString(@"CMLoginViewController")],
        @"handleForceLogout must transition root to CMLoginViewController");
}

- (void)testHandleSessionOpenedDoesNotCrash {
    // handleSessionOpened: is intentionally a no-op; just verify it doesn't crash.
    NSNotification *n = [NSNotification notificationWithName:@"CMSessionDidOpenNotification"
                                                      object:nil];
    XCTAssertNoThrow([self.sceneDelegate handleSessionOpened:n]);
}

- (void)testHandleLoginSuccess_SetsMainRootController {
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    NSNotification *n = [NSNotification notificationWithName:@"CMLoginDidSucceedNotification"
                                                      object:nil];
    // showMainInterface calls setRootViewController:animated: synchronously
    // (animated=NO because there is no prior rootViewController).
    [self.sceneDelegate handleLoginSuccess:n];

    XCTAssertNotNil(self.sceneDelegate.window.rootViewController,
                    @"handleLoginSuccess must install a root view controller");
    // On a non-iPad trait collection the root must be a UITabBarController.
    XCTAssertTrue(
        [self.sceneDelegate.window.rootViewController isKindOfClass:[UITabBarController class]],
        @"handleLoginSuccess for a courier must produce a UITabBarController root");
}

- (void)testHandleCoreDataReady_True_SetsCoreDataReadyFlag {
    NSNotification *n = [NSNotification notificationWithName:@"CMCoreDataDidBecomeReadyNotification"
                                                      object:@YES];
    [self.sceneDelegate handleCoreDataReady:n];
    BOOL ready = [[self.sceneDelegate valueForKey:@"coreDataReady"] boolValue];
    XCTAssertTrue(ready,
                  @"handleCoreDataReady:@YES must set the coreDataReady property to YES");
}

- (void)testHandleCoreDataReady_False_ClearsCoreDataReadyFlag {
    // Prime the flag to YES first so a default-NO cannot produce a false pass.
    NSNotification *yes = [NSNotification notificationWithName:@"CMCoreDataDidBecomeReadyNotification"
                                                        object:@YES];
    [self.sceneDelegate handleCoreDataReady:yes];
    XCTAssertTrue([[self.sceneDelegate valueForKey:@"coreDataReady"] boolValue],
                  @"pre-condition: flag must be YES before sending NO");

    NSNotification *no = [NSNotification notificationWithName:@"CMCoreDataDidBecomeReadyNotification"
                                                       object:@NO];
    [self.sceneDelegate handleCoreDataReady:no];
    BOOL ready = [[self.sceneDelegate valueForKey:@"coreDataReady"] boolValue];
    XCTAssertFalse(ready,
                   @"handleCoreDataReady:@NO must set the coreDataReady property to NO");
}

#pragma mark - Activity Tracking

- (void)testActivityDetectedDoesNotCrash {
    // Just calls CMSessionManager.recordActivity — no crash expected.
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    XCTAssertNoThrow([self.sceneDelegate activityDetected:tap]);
}

#pragma mark - Register Session Notifications

- (void)testRegisterSessionNotificationsDoesNotCrash {
    XCTAssertNoThrow([self.sceneDelegate registerSessionNotifications]);
}

@end
