//
//  SceneDelegate.m
//  CourierMatch
//
//  Step 11 wiring: root controller (login-or-main), activity tracking
//  gesture recognizer (Q20), session lifecycle notifications.
//

#import "SceneDelegate.h"
#import "CMSessionManager.h"
#import "CMTenantContext.h"
#import "CMLoginViewController.h"
#import "CMUserAccount.h"
#import "CMTheme.h"
#import "CMDebugLogger.h"
#import "CMItineraryListViewController.h"
#import "CMOrderListViewController.h"
#import "CMNotificationListViewController.h"
#import "CMScorecardViewController.h"
#import "CMScorecardListViewController.h"
#import "CMAdminDashboardViewController.h"

#pragma mark - Activity Tracking Gesture Recognizer (Q20)

/// A non-cancelling gesture recognizer that silently records every touch on
/// the window as user activity, feeding CMSessionManager.recordActivity.
/// Installed on every scene's root UIWindow per design.md Q20.
@interface CMActivityTrackingGestureRecognizer : UIGestureRecognizer
@end

@implementation CMActivityTrackingGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    self = [super initWithTarget:target action:action];
    if (self) {
        self.cancelsTouchesInView = NO;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = NO;
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    // Immediately fail so we never interfere with other recognizers but still
    // record the touch event.
    self.state = UIGestureRecognizerStateFailed;
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    return NO;
}

@end

#pragma mark - SceneDelegate

@interface SceneDelegate ()
@property (nonatomic, assign) BOOL coreDataReady;
@end

@implementation SceneDelegate

#pragma mark - Scene lifecycle

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {

    UIWindowScene *windowScene = (UIWindowScene *)scene;
    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.tintColor = [CMTheme cm_primaryColor];

    // Install activity tracking gesture recognizer on the window (Q20).
    [self installActivityTrackingRecognizer];

    // Determine initial root: authenticated → main interface, else → login.
    if ([[CMTenantContext shared] isAuthenticated] &&
        [[CMSessionManager shared] hasActiveSession]) {
        [self showMainInterface];
    } else {
        [self showLoginInterface];
    }

    [self.window makeKeyAndVisible];

    // Register for session notifications.
    [self registerSessionNotifications];

    // Register for login success notification.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleLoginSuccess:)
                                                 name:CMLoginDidSucceedNotification
                                               object:nil];

    // Register for Core Data readiness (login screen tolerates brief loading).
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleCoreDataReady:)
                                                 name:@"CMCoreDataDidBecomeReadyNotification"
                                               object:nil];
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [[CMSessionManager shared] handleSceneDidBecomeActive];
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // No-op; background entry is handled in sceneDidEnterBackground.
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // handleSceneDidBecomeActive will fire shortly.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    [[CMSessionManager shared] handleSceneDidEnterBackground];
}

#pragma mark - Activity Tracking (Q20)

- (void)installActivityTrackingRecognizer {
    CMActivityTrackingGestureRecognizer *recognizer =
        [[CMActivityTrackingGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(activityDetected:)];
    [self.window addGestureRecognizer:recognizer];
}

- (void)activityDetected:(UIGestureRecognizer *)recognizer {
    [[CMSessionManager shared] recordActivity];
}

#pragma mark - Session Notifications

- (void)registerSessionNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(handleSessionExpired:)
               name:CMSessionDidExpireNotification
             object:nil];

    [nc addObserver:self
           selector:@selector(handleForceLogout:)
               name:CMSessionDidForceLogoutNotification
             object:nil];

    [nc addObserver:self
           selector:@selector(handleSessionOpened:)
               name:CMSessionDidOpenNotification
             object:nil];
}

- (void)handleSessionExpired:(NSNotification *)notification {
    CMLogInfo(@"scene", @"session expired — presenting login");
    [self transitionToLoginWithMessage:@"Your session has expired. Please sign in again."];
}

- (void)handleForceLogout:(NSNotification *)notification {
    CMLogInfo(@"scene", @"forced logout — presenting login");
    [self transitionToLoginWithMessage:@"You have been signed out by an administrator."];
}

- (void)handleSessionOpened:(NSNotification *)notification {
    // Session opened via login — main interface transition is handled
    // by handleLoginSuccess: which fires after the auth service posts.
}

- (void)handleLoginSuccess:(NSNotification *)notification {
    CMLogInfo(@"scene", @"login succeeded — transitioning to main interface");
    [self showMainInterface];
}

- (void)handleCoreDataReady:(NSNotification *)notification {
    BOOL ok = [notification.object boolValue];
    self.coreDataReady = ok;
    if (!ok) {
        CMLogError(@"scene", @"core data not ready — cannot proceed");
    }
}

#pragma mark - Root Controller Management

- (void)showLoginInterface {
    CMLoginViewController *loginVC = [[CMLoginViewController alloc] init];
    [self setRootViewController:loginVC animated:(self.window.rootViewController != nil)];
}

- (void)showMainInterface {
    UIViewController *mainVC = [self buildMainViewController];
    [self setRootViewController:mainVC animated:(self.window.rootViewController != nil)];
}

- (void)transitionToLoginWithMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Dismiss any presented controllers
        if (self.window.rootViewController.presentedViewController) {
            [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        }

        CMLoginViewController *loginVC = [[CMLoginViewController alloc] init];
        [self setRootViewController:loginVC animated:YES];

        // Show alert with the expiry/logout message
        if (message) {
            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Signed Out"
                                                   message:message
                                            preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            // Present on next run loop tick to ensure the new root is installed
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.window.rootViewController presentViewController:alert
                                                             animated:YES
                                                           completion:nil];
            });
        }
    });
}

- (void)setRootViewController:(UIViewController *)vc animated:(BOOL)animated {
    if (!animated) {
        self.window.rootViewController = vc;
        return;
    }
    UIView *snapshot = [self.window snapshotViewAfterScreenUpdates:YES];
    if (snapshot) {
        [vc.view addSubview:snapshot];
    }
    self.window.rootViewController = vc;
    if (snapshot) {
        [UIView animateWithDuration:0.3
                         animations:^{
            snapshot.alpha = 0;
            snapshot.transform = CGAffineTransformMakeScale(0.95, 0.95);
        } completion:^(BOOL finished) {
            [snapshot removeFromSuperview];
        }];
    }
}

#pragma mark - Main Interface Builder

- (UIViewController *)buildMainViewController {
    UITraitCollection *traits = self.window.windowScene.traitCollection;

    if (traits.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return [self buildSplitViewController];
    } else {
        return [self buildTabBarController];
    }
}

/// iPhone: UITabBarController with role-aware tabs per §2.4.
- (UITabBarController *)buildTabBarController {
    UITabBarController *tabBar = [[UITabBarController alloc] init];
    tabBar.viewControllers = [self buildTabViewControllers];
    tabBar.tabBar.tintColor = [CMTheme cm_primaryColor];
    return tabBar;
}

/// iPad: UISplitViewController (three-column where available) per §2.4.
- (UISplitViewController *)buildSplitViewController {
    UISplitViewController *split;
    if (@available(iOS 14.0, *)) {
        split = [[UISplitViewController alloc] initWithStyle:UISplitViewControllerStyleTripleColumn];
        split.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
        split.preferredSplitBehavior = UISplitViewControllerSplitBehaviorTile;

        // Primary = role sidebar
        UIViewController *sidebar = [self buildSidebarViewController];
        [split setViewController:sidebar forColumn:UISplitViewControllerColumnPrimary];

        // Supplementary = placeholder list
        UIViewController *supplementary = [self buildPlaceholderListViewController];
        [split setViewController:supplementary forColumn:UISplitViewControllerColumnSupplementary];

        // Secondary = placeholder detail
        UIViewController *detail = [self buildPlaceholderDetailViewController];
        [split setViewController:detail forColumn:UISplitViewControllerColumnSecondary];

        // Compact fallback: the tab bar (via setViewController:forColumn:compact)
        [split setViewController:[self buildTabBarController] forColumn:UISplitViewControllerColumnCompact];
    } else {
        split = [[UISplitViewController alloc] init];
        split.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
        UINavigationController *primary = [[UINavigationController alloc]
            initWithRootViewController:[self buildSidebarViewController]];
        UINavigationController *secondary = [[UINavigationController alloc]
            initWithRootViewController:[self buildPlaceholderDetailViewController]];
        split.viewControllers = @[primary, secondary];
    }
    return split;
}

/// Role-aware tab view controllers. Tabs depend on the current user's role.
- (NSArray<UIViewController *> *)buildTabViewControllers {
    NSMutableArray<UIViewController *> *tabs = [NSMutableArray array];
    NSString *role = [CMTenantContext shared].currentRole;

    // Itineraries tab — available to all roles
    {
        CMItineraryListViewController *vc = [[CMItineraryListViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) { image = [UIImage systemImageNamed:@"map"]; }
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Itineraries" image:image tag:0];
        nav.tabBarItem.accessibilityLabel = @"Itineraries";
        [tabs addObject:nav];
    }

    // Orders tab — available to all roles
    {
        CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) { image = [UIImage systemImageNamed:@"shippingbox"]; }
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Orders" image:image tag:1];
        nav.tabBarItem.accessibilityLabel = @"Orders";
        [tabs addObject:nav];
    }

    // Notifications tab — available to all roles
    {
        CMNotificationListViewController *vc = [[CMNotificationListViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) { image = [UIImage systemImageNamed:@"bell"]; }
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Notifications" image:image tag:2];
        nav.tabBarItem.accessibilityLabel = @"Notifications";
        [tabs addObject:nav];
    }

    // Scoring/Appeals tab — available to reviewers, finance, and admin only.
    // Per prompt: manual review belongs to Reviewers, financial adjustments to Finance.
    if ([role isEqualToString:CMUserRoleReviewer] ||
        [role isEqualToString:CMUserRoleFinance] ||
        [role isEqualToString:CMUserRoleAdmin]) {
        // CMScorecardViewController requires a scorecard instance; use a
        // placeholder list that can push into it when a scorecard is selected.
        UIViewController *vc = [self scoringPlaceholderViewController];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) { image = [UIImage systemImageNamed:@"star"]; }
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Scoring" image:image tag:3];
        nav.tabBarItem.accessibilityLabel = @"Scoring";
        [tabs addObject:nav];
    }

    // Admin tab — only for admin users
    if ([role isEqualToString:CMUserRoleAdmin]) {
        CMAdminDashboardViewController *vc = [[CMAdminDashboardViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        UIImage *image = nil;
        if (@available(iOS 13.0, *)) { image = [UIImage systemImageNamed:@"gearshape"]; }
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Admin" image:image tag:4];
        nav.tabBarItem.accessibilityLabel = @"Admin";
        [tabs addObject:nav];
    }

    return [tabs copy];
}

/// Scoring tab: real scorecard list that shows all delivered orders and their
/// scorecard status. Replaces the former placeholder.
- (UIViewController *)scoringPlaceholderViewController {
    return [[CMScorecardListViewController alloc] init];
}

/// iPad sidebar listing role-specific navigation items.
- (UIViewController *)buildSidebarViewController {
    UIViewController *sidebar = [[UIViewController alloc] init];
    sidebar.view.backgroundColor = [CMTheme cm_secondaryBackgroundColor];
    sidebar.title = @"CourierMatch";

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.alignment = UIStackViewAlignmentFill;
    [sidebar.view addSubview:stack];

    UILayoutGuide *safe = sidebar.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
    ]];

    NSArray<NSString *> *items = @[@"Itineraries", @"Orders", @"Notifications", @"Scoring", @"Admin"];
    NSString *role = [CMTenantContext shared].currentRole;

    for (NSString *item in items) {
        // Filter admin tab for non-admin roles
        if ([item isEqualToString:@"Admin"] && ![role isEqualToString:CMUserRoleAdmin]) {
            continue;
        }
        // Filter scoring tab to reviewer/finance/admin only
        if ([item isEqualToString:@"Scoring"] &&
            !([role isEqualToString:CMUserRoleReviewer] ||
              [role isEqualToString:CMUserRoleFinance] ||
              [role isEqualToString:CMUserRoleAdmin])) {
            continue;
        }

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:item forState:UIControlStateNormal];
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        button.titleLabel.font = [CMTheme cm_fontForTextStyle:UIFontTextStyleBody];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        [button setTitleColor:[CMTheme cm_labelColor] forState:UIControlStateNormal];
        button.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
        button.accessibilityLabel = item;
        button.accessibilityHint = [NSString stringWithFormat:@"Navigate to %@", item];
        [button addTarget:self action:@selector(sidebarItemTapped:) forControlEvents:UIControlEventTouchUpInside];

        NSLayoutConstraint *height = [button.heightAnchor constraintGreaterThanOrEqualToConstant:44];
        height.active = YES;

        [stack addArrangedSubview:button];
    }

    // Logout button at bottom
    UIButton *logoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [logoutButton setTitle:@"Sign Out" forState:UIControlStateNormal];
    [logoutButton setTitleColor:[CMTheme cm_errorColor] forState:UIControlStateNormal];
    logoutButton.titleLabel.font = [CMTheme cm_fontForTextStyle:UIFontTextStyleBody];
    logoutButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    logoutButton.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    logoutButton.accessibilityLabel = @"Sign Out";
    logoutButton.accessibilityHint = @"Double tap to sign out";
    [logoutButton addTarget:self action:@selector(logoutTapped:) forControlEvents:UIControlEventTouchUpInside];

    NSLayoutConstraint *logoutHeight = [logoutButton.heightAnchor constraintGreaterThanOrEqualToConstant:44];
    logoutHeight.active = YES;

    [stack addArrangedSubview:logoutButton];

    return sidebar;
}

- (void)sidebarItemTapped:(UIButton *)sender {
    NSString *title = [sender titleForState:UIControlStateNormal];
    UIViewController *vc = [self viewControllerForSidebarItem:title];
    if (!vc) return;

    // On iPad, push into the split view's supplementary column
    UIViewController *root = self.window.rootViewController;
    if ([root isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController *split = (UISplitViewController *)root;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.navigationBar.prefersLargeTitles = YES;
        if (@available(iOS 14.0, *)) {
            [split setViewController:nav forColumn:UISplitViewControllerColumnSupplementary];
        } else {
            split.viewControllers = @[split.viewControllers.firstObject ?: [[UIViewController alloc] init], nav];
        }
    }
}

- (UIViewController *)viewControllerForSidebarItem:(NSString *)title {
    if ([title isEqualToString:@"Itineraries"]) {
        return [[CMItineraryListViewController alloc] init];
    } else if ([title isEqualToString:@"Orders"]) {
        return [[CMOrderListViewController alloc] init];
    } else if ([title isEqualToString:@"Notifications"]) {
        return [[CMNotificationListViewController alloc] init];
    } else if ([title isEqualToString:@"Scoring"]) {
        return [self scoringPlaceholderViewController];
    } else if ([title isEqualToString:@"Admin"]) {
        return [[CMAdminDashboardViewController alloc] init];
    }
    return nil;
}

- (UIViewController *)buildPlaceholderListViewController {
    // Default supplementary column: show orders list
    CMOrderListViewController *vc = [[CMOrderListViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.prefersLargeTitles = YES;
    return nav;
}

- (UIViewController *)buildPlaceholderDetailViewController {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [CMTheme cm_backgroundColor];
    vc.title = @"Detail";

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = @"No Selection";
    label.textAlignment = NSTextAlignmentCenter;
    [CMTheme cm_configureLabel:label
                     textStyle:UIFontTextStyleBody
                         color:[CMTheme cm_secondaryLabelColor]];
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.centerYAnchor],
    ]];

    return vc;
}

#pragma mark - Logout

- (void)logoutTapped:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign Out"
                                                                   message:@"Are you sure you want to sign out?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Sign Out"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[CMSessionManager shared] logout];
        [self showLoginInterface];
    }]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
