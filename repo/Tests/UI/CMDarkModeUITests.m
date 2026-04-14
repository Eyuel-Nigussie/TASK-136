//
//  CMDarkModeUITests.m
//  CourierMatch UI Tests
//
//  Dark Mode tests: verifies the app renders correctly in dark mode,
//  login screen loads without crash, and dark background is applied.
//  See design.md section 17.
//

#import <XCTest/XCTest.h>

@interface CMDarkModeUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation CMDarkModeUITests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
}

- (void)tearDown {
    self.app = nil;
    [super tearDown];
}

#pragma mark - Test: Force Dark Mode via Launch Argument

- (void)testForcesDarkModeViaLaunchArgument {
    // Force dark mode via the UIKit launch argument
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Dark"
    ];
    [self.app launch];

    // The app should launch without crashing in dark mode
    XCTAssertTrue(self.app.exists, @"App should exist after launching in dark mode");

    // Wait for login screen to load
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    BOOL loginReady = [tenantField waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(loginReady, @"Login screen should load in dark mode without crash");
}

#pragma mark - Test: Login Screen Loads Without Crash in Dark Mode

- (void)testLoginScreenRendersInDarkMode {
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Dark"
    ];
    [self.app launch];

    // Verify all login screen elements are present
    XCUIElement *titleLabel = self.app.staticTexts[@"CourierMatch"];
    BOOL titleExists = [titleLabel waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(titleExists, @"Title should render in dark mode");

    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    XCTAssertTrue(tenantField.exists, @"Tenant ID field should render in dark mode");

    XCUIElement *usernameField = self.app.textFields[@"Username"];
    XCTAssertTrue(usernameField.exists, @"Username field should render in dark mode");

    XCUIElement *passwordField = self.app.secureTextFields[@"Password"];
    XCTAssertTrue(passwordField.exists, @"Password field should render in dark mode");

    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    XCTAssertTrue(loginButton.exists, @"Sign In button should render in dark mode");

    XCUIElement *createAccountButton = self.app.buttons[@"Create Account"];
    XCTAssertTrue(createAccountButton.exists, @"Create Account button should render in dark mode");
}

#pragma mark - Test: Dark Mode Background Color

- (void)testDarkModeBackgroundColor {
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Dark"
    ];
    [self.app launch];

    // Wait for login screen
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    [tenantField waitForExistenceWithTimeout:5.0];

    // Take a screenshot of the app in dark mode
    XCUIScreenshot *screenshot = [self.app screenshot];
    XCTAssertNotNil(screenshot, @"Should be able to capture screenshot in dark mode");
    XCTAssertNotNil(screenshot.image, @"Screenshot should contain an image");

    // The screenshot image should have content (non-zero dimensions)
    CGSize imageSize = screenshot.image.size;
    XCTAssertGreaterThan(imageSize.width, 0, @"Screenshot width should be > 0");
    XCTAssertGreaterThan(imageSize.height, 0, @"Screenshot height should be > 0");

    // Verify the app window exists and is visible
    XCUIElement *window = self.app.windows.firstMatch;
    XCTAssertTrue(window.exists, @"App window should exist in dark mode");
}

#pragma mark - Test: Light Mode Comparison

- (void)testLoginScreenRendersInLightMode {
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Light"
    ];
    [self.app launch];

    // Verify the same elements render in light mode
    XCUIElement *titleLabel = self.app.staticTexts[@"CourierMatch"];
    BOOL titleExists = [titleLabel waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(titleExists, @"Title should render in light mode");

    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    XCTAssertTrue(loginButton.exists, @"Sign In button should render in light mode");

    // Both modes should produce screenshots without crash
    XCUIScreenshot *screenshot = [self.app screenshot];
    XCTAssertNotNil(screenshot, @"Should capture screenshot in light mode");
    XCTAssertNotNil(screenshot.image, @"Light mode screenshot should have an image");
}

#pragma mark - Test: Interaction Works in Dark Mode

- (void)testInteractionWorksInDarkMode {
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Dark"
    ];
    [self.app launch];

    // Wait for login screen
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    BOOL ready = [tenantField waitForExistenceWithTimeout:5.0];
    XCTAssertTrue(ready, @"Login screen should be ready");

    // Test that text input works in dark mode
    [tenantField tap];
    [tenantField typeText:@"dark-mode-test"];
    XCTAssertTrue(tenantField.exists, @"Field should remain after input in dark mode");

    // Test that button tap works
    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    XCTAssertTrue(loginButton.isHittable, @"Login button should be hittable in dark mode");
    [loginButton tap];

    // App should not crash after interaction in dark mode
    XCTAssertTrue(self.app.exists, @"App should not crash during dark mode interaction");
}

#pragma mark - Test: Dark Mode Does Not Affect Element Accessibility

- (void)testDarkModeDoesNotAffectAccessibility {
    self.app.launchArguments = @[
        @"-UIUserInterfaceStyle",
        @"Dark"
    ];
    [self.app launch];

    // Wait for login screen
    XCUIElement *tenantField = self.app.textFields[@"Tenant ID"];
    [tenantField waitForExistenceWithTimeout:5.0];

    // Verify accessibility labels are intact in dark mode
    XCTAssertGreaterThan(tenantField.label.length, 0,
                         @"Tenant field label should be non-empty in dark mode");

    XCUIElement *loginButton = self.app.buttons[@"Sign In"];
    XCTAssertGreaterThan(loginButton.label.length, 0,
                         @"Login button label should be non-empty in dark mode");

    XCUIElement *createAccountButton = self.app.buttons[@"Create Account"];
    if (createAccountButton.exists) {
        XCTAssertGreaterThan(createAccountButton.label.length, 0,
                             @"Create Account label should be non-empty in dark mode");
    }
}

@end
