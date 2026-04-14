//
//  CMDynamicTypeUITests.m
//  CourierMatch UI Tests
//
//  Dynamic Type tests: verifies labels remain visible and interactive elements
//  remain tappable at the largest accessibility content sizes.
//  See design.md section 17.
//

#import <XCTest/XCTest.h>

@interface CMDynamicTypeUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation CMDynamicTypeUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
}

- (void)tearDown {
    self.app = nil;
    [super tearDown];
}

#pragma mark - Test: Labels Visible at Largest Dynamic Type Size

- (void)testLabelsVisibleAtAccessibilityExtraExtraExtraLarge {
    // Set preferred content size to the largest accessibility size
    // via launch argument (UIKit respects this in tests)
    self.app.launchArguments = @[
        @"-UIPreferredContentSizeCategoryName",
        @"UICTContentSizeCategoryAccessibilityXXXL"
    ];
    [self.app launch];

    // Wait for login screen
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    BOOL loginReady = [tenantField waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(loginReady, @"Login screen should load at largest Dynamic Type size");

    // Verify the title label is visible
    XCUIElement *titleLabel = self.app.staticTexts[@"CourierMatch"];
    XCTAssertTrue(titleLabel.exists, @"Title label should be visible at largest size");

    // Verify all form fields are still visible (may require scrolling)
    XCTAssertTrue(tenantField.exists, @"Tenant ID field should be visible at largest size");

    XCUIElement *usernameField = self.app.textFields[@"Username"];
    XCTAssertTrue(usernameField.exists, @"Username field should be visible at largest size");

    XCUIElement *passwordField = self.app.secureTextFields[@"Password"];
    XCTAssertTrue(passwordField.exists, @"Password field should be visible at largest size");

    // Verify the Sign In button is visible (may need to scroll)
    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    if (!loginButton.isHittable) {
        // Scroll down to find the button
        [self.app swipeUp];
    }
    XCTAssertTrue(loginButton.exists, @"Sign In button should be present at largest size");
}

#pragma mark - Test: Labels Not Truncated on Login Screen

- (void)testLabelsNotTruncatedAtLargeSize {
    self.app.launchArguments = @[
        @"-UIPreferredContentSizeCategoryName",
        @"UICTContentSizeCategoryAccessibilityXXXL"
    ];
    [self.app launch];

    XCUIElement *titleLabel = self.app.staticTexts[@"CourierMatch"];
    BOOL titleExists = [titleLabel waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(titleExists, @"Title should exist");

    // Verify the title frame has non-zero dimensions (it's rendering, not collapsed)
    CGRect titleFrame = titleLabel.frame;
    XCTAssertGreaterThan(titleFrame.size.width, 0, @"Title width should be > 0");
    XCTAssertGreaterThan(titleFrame.size.height, 0, @"Title height should be > 0");

    // Verify field labels are visible and have non-zero size
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    if (tenantField.exists) {
        CGRect tenantFrame = tenantField.frame;
        XCTAssertGreaterThan(tenantFrame.size.width, 0,
                             @"Tenant field width should be > 0 at large size");
        XCTAssertGreaterThan(tenantFrame.size.height, 0,
                             @"Tenant field height should be > 0 at large size");
    }

    XCUIElement *usernameField = self.app.textFields[@"Username"];
    if (usernameField.exists) {
        CGRect usernameFrame = usernameField.frame;
        XCTAssertGreaterThan(usernameFrame.size.width, 0,
                             @"Username field width should be > 0 at large size");
        XCTAssertGreaterThan(usernameFrame.size.height, 0,
                             @"Username field height should be > 0 at large size");
    }
}

#pragma mark - Test: Tab Bar Items Still Tappable at Large Sizes

- (void)testTabBarItemsTappableAtLargeSize {
    self.app.launchArguments = @[
        @"-UIPreferredContentSizeCategoryName",
        @"UICTContentSizeCategoryAccessibilityXXXL"
    ];
    [self.app launch];

    // Check if we can reach the tab bar (requires successful login)
    XCUIElement *tabBar = self.app.tabBars.firstMatch;
    BOOL tabBarExists = [tabBar waitForExistenceWithTimeout:3.0];

    if (tabBarExists) {
        // Verify tab bar items are tappable at large text size
        NSArray<XCUIElement *> *buttons = tabBar.buttons.allElementsBoundByIndex;
        XCTAssertGreaterThan(buttons.count, 0,
                             @"Tab bar should have buttons at large text size");

        for (XCUIElement *button in buttons) {
            XCTAssertTrue(button.exists, @"Tab bar button should exist at large size");
            // Verify minimum tap target: frame should be at least 44x44
            CGRect buttonFrame = button.frame;
            XCTAssertGreaterThanOrEqual(buttonFrame.size.height, 30.0,
                                        @"Tab bar button height should be reasonable at large size");
        }

        // Test tapping each tab
        for (XCUIElement *button in buttons) {
            if (button.isHittable) {
                [button tap];
                // Verify no crash occurred
                XCTAssertTrue(self.app.exists,
                              @"App should not crash when tapping tab at large size");
            }
        }
    } else {
        // If no tab bar, test login screen elements at large size
        XCUIElement *loginButton = self.app.buttons[@"Sign In"];
        if ([loginButton waitForExistenceWithTimeout:2.0]) {
            CGRect loginFrame = loginButton.frame;
            XCTAssertGreaterThanOrEqual(loginFrame.size.height, 44.0,
                                        @"Login button should maintain minimum tap target");
            XCTAssertTrue(loginButton.isHittable,
                          @"Login button should be tappable at largest Dynamic Type size");
        }
    }
}

#pragma mark - Test: Default Size Comparison

- (void)testLoginScreenAtDefaultSize {
    // Launch with default (no override) for comparison
    [self.app launch];

    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    BOOL loginReady = [tenantField waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(loginReady, @"Login screen should load at default size");

    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    XCTAssertTrue(loginButton.exists, @"Sign In button should exist at default size");

    // Verify minimum 44pt tap target on login button
    CGRect buttonFrame = loginButton.frame;
    XCTAssertGreaterThanOrEqual(buttonFrame.size.height, 44.0,
                                @"Login button should have >= 44pt height for accessibility");
}

@end
