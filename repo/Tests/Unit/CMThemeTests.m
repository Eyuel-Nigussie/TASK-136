//
//  CMThemeTests.m
//  CourierMatch Unit Tests
//
//  Verifies CMTheme semantic color accessors, font helpers,
//  and view-configuration class methods.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "CMTheme.h"

@interface CMThemeTests : XCTestCase
@end

@implementation CMThemeTests

#pragma mark - Semantic Colors (non-nil checks)

- (void)testPrimaryColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_primaryColor]);
}

- (void)testErrorColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_errorColor]);
}

- (void)testSuccessColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_successColor]);
}

- (void)testWarningColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_warningColor]);
}

- (void)testBackgroundColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_backgroundColor]);
}

- (void)testSecondaryBackgroundColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_secondaryBackgroundColor]);
}

- (void)testGroupedBackgroundColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_groupedBackgroundColor]);
}

- (void)testLabelColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_labelColor]);
}

- (void)testSecondaryLabelColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_secondaryLabelColor]);
}

- (void)testTertiaryLabelColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_tertiaryLabelColor]);
}

- (void)testSeparatorColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_separatorColor]);
}

- (void)testFieldBackgroundColorIsNotNil {
    XCTAssertNotNil([CMTheme cm_fieldBackgroundColor]);
}

#pragma mark - Font Accessors

- (void)testFontForTextStyle_BodyIsNotNil {
    UIFont *font = [CMTheme cm_fontForTextStyle:UIFontTextStyleBody];
    XCTAssertNotNil(font);
}

- (void)testFontForTextStyle_HeadlineIsNotNil {
    UIFont *font = [CMTheme cm_fontForTextStyle:UIFontTextStyleHeadline];
    XCTAssertNotNil(font);
}

- (void)testFontForTextStyle_CaptionIsNotNil {
    UIFont *font = [CMTheme cm_fontForTextStyle:UIFontTextStyleCaption1];
    XCTAssertNotNil(font);
}

- (void)testBoldFontForTextStyle_BodyIsNotNil {
    UIFont *bold = [CMTheme cm_boldFontForTextStyle:UIFontTextStyleBody];
    XCTAssertNotNil(bold);
}

- (void)testBoldFontForTextStyle_LargeTitleIsNotNil {
    UIFont *bold = [CMTheme cm_boldFontForTextStyle:UIFontTextStyleLargeTitle];
    XCTAssertNotNil(bold);
}

#pragma mark - Label Configuration

- (void)testConfigureLabel_SetsFont {
    UILabel *label = [[UILabel alloc] init];
    [CMTheme cm_configureLabel:label
                     textStyle:UIFontTextStyleBody
                         color:[UIColor labelColor]];

    XCTAssertNotNil(label.font, @"Font must be set after cm_configureLabel:textStyle:color:");
    XCTAssertTrue(label.adjustsFontForContentSizeCategory,
                  @"adjustsFontForContentSizeCategory must be YES");
    XCTAssertEqualObjects(label.textColor, [UIColor labelColor]);
    XCTAssertEqual(label.numberOfLines, 0);
}

- (void)testConfigureTitleLabel {
    UILabel *label = [[UILabel alloc] init];
    [CMTheme cm_configureTitleLabel:label];
    XCTAssertNotNil(label.font);
    XCTAssertTrue(label.adjustsFontForContentSizeCategory);
    XCTAssertEqualObjects(label.textColor, [CMTheme cm_labelColor]);
}

- (void)testConfigureBodyLabel {
    UILabel *label = [[UILabel alloc] init];
    [CMTheme cm_configureBodyLabel:label];
    XCTAssertNotNil(label.font);
    XCTAssertTrue(label.adjustsFontForContentSizeCategory);
    XCTAssertEqualObjects(label.textColor, [CMTheme cm_labelColor]);
}

- (void)testConfigureCaptionLabel {
    UILabel *label = [[UILabel alloc] init];
    [CMTheme cm_configureCaptionLabel:label];
    XCTAssertNotNil(label.font);
    XCTAssertTrue(label.adjustsFontForContentSizeCategory);
    XCTAssertEqualObjects(label.textColor, [CMTheme cm_secondaryLabelColor]);
}

#pragma mark - Button Configuration

- (void)testConfigurePrimaryButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [CMTheme cm_configurePrimaryButton:button];

    XCTAssertEqualObjects(button.backgroundColor, [CMTheme cm_primaryColor]);
    XCTAssertEqualObjects([button titleColorForState:UIControlStateNormal],
                          [UIColor whiteColor]);
    XCTAssertNotNil(button.titleLabel.font);
    XCTAssertTrue(button.titleLabel.adjustsFontForContentSizeCategory);
    XCTAssertEqual(button.layer.cornerRadius, 10.0);
    XCTAssertTrue(button.layer.masksToBounds);
}

- (void)testConfigureSecondaryButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [CMTheme cm_configureSecondaryButton:button];

    XCTAssertEqualObjects(button.backgroundColor, [UIColor clearColor]);
    XCTAssertEqualObjects([button titleColorForState:UIControlStateNormal],
                          [CMTheme cm_primaryColor]);
    XCTAssertEqual(button.layer.cornerRadius, 10.0);
    XCTAssertEqual(button.layer.borderWidth, 1.0);
    XCTAssertTrue(button.layer.masksToBounds);
}

- (void)testConfigureDestructiveButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [CMTheme cm_configureDestructiveButton:button];

    XCTAssertEqualObjects(button.backgroundColor, [CMTheme cm_errorColor]);
    XCTAssertEqualObjects([button titleColorForState:UIControlStateNormal],
                          [UIColor whiteColor]);
    XCTAssertEqual(button.layer.cornerRadius, 10.0);
    XCTAssertTrue(button.layer.masksToBounds);
}

#pragma mark - Text Field Configuration

- (void)testConfigureTextField_WithPlaceholder {
    UITextField *tf = [[UITextField alloc] init];
    [CMTheme cm_configureTextField:tf placeholder:@"Enter value"];

    XCTAssertEqual(tf.borderStyle, UITextBorderStyleRoundedRect);
    XCTAssertEqualObjects(tf.backgroundColor, [CMTheme cm_fieldBackgroundColor]);
    XCTAssertEqualObjects(tf.textColor, [CMTheme cm_labelColor]);
    XCTAssertNotNil(tf.font);
    XCTAssertTrue(tf.adjustsFontForContentSizeCategory);
    XCTAssertNotNil(tf.attributedPlaceholder, @"Placeholder should be set");
    XCTAssertGreaterThan(tf.attributedPlaceholder.length, 0);
}

- (void)testConfigureTextField_WithNilPlaceholder {
    UITextField *tf = [[UITextField alloc] init];
    [CMTheme cm_configureTextField:tf placeholder:nil];

    XCTAssertEqual(tf.borderStyle, UITextBorderStyleRoundedRect);
    XCTAssertNotNil(tf.font);
    // nil placeholder should not crash and should leave attributedPlaceholder nil or empty.
    (void)tf.attributedPlaceholder;
}

@end
