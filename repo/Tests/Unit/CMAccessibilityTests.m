//
//  CMAccessibilityTests.m
//  CourierMatch Unit Tests
//
//  Tests for UIView+CMAccessibility category:
//  cm_setAccessibilityLabel:hint:, cm_enforceMinimumTapTarget,
//  and cm_configureAccessibilityWithLabel:hint:.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "UIView+CMAccessibility.h"

@interface CMAccessibilityTests : XCTestCase
@property (nonatomic, strong) UIView *view;
@end

@implementation CMAccessibilityTests

- (void)setUp {
    [super setUp];
    // Use a plain UIView added to a window so AutoLayout constraints can activate.
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 812)];
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    [window addSubview:self.view];
}

#pragma mark - cm_setAccessibilityLabel:hint:

- (void)testSetAccessibilityLabelAndHint {
    [self.view cm_setAccessibilityLabel:@"My Label" hint:@"Double tap to activate"];
    XCTAssertEqualObjects(self.view.accessibilityLabel, @"My Label");
    XCTAssertEqualObjects(self.view.accessibilityHint, @"Double tap to activate");
}

- (void)testSetAccessibilityLabelNilHintDoesNotClear {
    self.view.accessibilityHint = @"Previous hint";
    [self.view cm_setAccessibilityLabel:@"Label" hint:nil];
    XCTAssertEqualObjects(self.view.accessibilityLabel, @"Label");
    // Nil hint: implementation only sets hint when hint != nil, so previous value preserved.
    XCTAssertEqualObjects(self.view.accessibilityHint, @"Previous hint");
}

- (void)testSetAccessibilityLabelEmptyHint {
    [self.view cm_setAccessibilityLabel:@"Button" hint:@""];
    XCTAssertEqualObjects(self.view.accessibilityLabel, @"Button");
    XCTAssertEqualObjects(self.view.accessibilityHint, @"");
}

#pragma mark - cm_enforceMinimumTapTarget

- (void)testEnforceMinimumTapTargetAddsConstraints {
    NSUInteger before = self.view.constraints.count;
    [self.view cm_enforceMinimumTapTarget];
    // Should add 2 constraints (width >= 44, height >= 44).
    XCTAssertEqual(self.view.constraints.count, before + 2,
                   @"Should add exactly 2 constraints for minimum tap target");
}

- (void)testEnforceMinimumTapTargetConstraintConstants {
    [self.view cm_enforceMinimumTapTarget];
    BOOL foundWidth = NO, foundHeight = NO;
    for (NSLayoutConstraint *c in self.view.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth) {
            XCTAssertEqual(c.constant, 44.0, @"Min width should be 44pt");
            foundWidth = YES;
        } else if (c.firstAttribute == NSLayoutAttributeHeight) {
            XCTAssertEqual(c.constant, 44.0, @"Min height should be 44pt");
            foundHeight = YES;
        }
    }
    XCTAssertTrue(foundWidth, @"Width constraint should be added");
    XCTAssertTrue(foundHeight, @"Height constraint should be added");
}

#pragma mark - cm_configureAccessibilityWithLabel:hint:

- (void)testConfigureAccessibilityWithLabelAndHint {
    [self.view cm_configureAccessibilityWithLabel:@"Action button"
                                            hint:@"Tap to submit"];

    XCTAssertTrue(self.view.isAccessibilityElement, @"isAccessibilityElement should be YES");
    XCTAssertEqualObjects(self.view.accessibilityLabel, @"Action button");
    XCTAssertEqualObjects(self.view.accessibilityHint, @"Tap to submit");
    // Should also enforce min tap target (adds 2 constraints).
    BOOL hasWidthConstraint = NO;
    for (NSLayoutConstraint *c in self.view.constraints) {
        if (c.firstAttribute == NSLayoutAttributeWidth) {
            hasWidthConstraint = YES;
        }
    }
    XCTAssertTrue(hasWidthConstraint, @"Min-tap-target width constraint should be present");
}

- (void)testConfigureAccessibilityIsAccessibilityElement {
    self.view.isAccessibilityElement = NO;
    [self.view cm_configureAccessibilityWithLabel:@"Close" hint:nil];
    XCTAssertTrue(self.view.isAccessibilityElement,
                  @"cm_configureAccessibilityWithLabel:hint: must set isAccessibilityElement = YES");
}

@end
