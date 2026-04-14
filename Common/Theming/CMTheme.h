//
//  CMTheme.h
//  CourierMatch
//
//  Semantic color and text style helpers per design.md §14.
//  All colors resolve to system semantic colors so Dark Mode is automatic.
//  Text style helpers produce Dynamic Type fonts with
//  `adjustsFontForContentSizeCategory = YES`.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMTheme : NSObject

#pragma mark - Semantic Colors

/// Primary accent color (tintColor). Uses `systemBlueColor`.
+ (UIColor *)cm_primaryColor;

/// Destructive / error emphasis. Uses `systemRedColor`.
+ (UIColor *)cm_errorColor;

/// Success emphasis. Uses `systemGreenColor`.
+ (UIColor *)cm_successColor;

/// Warning emphasis. Uses `systemOrangeColor`.
+ (UIColor *)cm_warningColor;

/// Primary background. Uses `systemBackgroundColor`.
+ (UIColor *)cm_backgroundColor;

/// Secondary (grouped) background. Uses `secondarySystemBackgroundColor`.
+ (UIColor *)cm_secondaryBackgroundColor;

/// Grouped table background. Uses `systemGroupedBackgroundColor`.
+ (UIColor *)cm_groupedBackgroundColor;

/// Primary label color. Uses `labelColor`.
+ (UIColor *)cm_labelColor;

/// Secondary label color. Uses `secondaryLabelColor`.
+ (UIColor *)cm_secondaryLabelColor;

/// Tertiary label color. Uses `tertiaryLabelColor`.
+ (UIColor *)cm_tertiaryLabelColor;

/// Separator color. Uses `separatorColor`.
+ (UIColor *)cm_separatorColor;

/// Fill color for text fields, search bars. Uses `tertiarySystemFillColor`.
+ (UIColor *)cm_fieldBackgroundColor;

#pragma mark - Text Style Fonts

/// Returns a UIFont for the given text style, configured for Dynamic Type.
+ (UIFont *)cm_fontForTextStyle:(UIFontTextStyle)style;

/// Returns a bold variant of the Dynamic Type font for the given text style.
+ (UIFont *)cm_boldFontForTextStyle:(UIFontTextStyle)style;

#pragma mark - Label Configuration

/// Configures a UILabel with the given text style, Dynamic Type, and semantic color.
+ (void)cm_configureLabel:(UILabel *)label
                textStyle:(UIFontTextStyle)style
                    color:(UIColor *)color;

/// Configures a UILabel as a title (large title text style, label color).
+ (void)cm_configureTitleLabel:(UILabel *)label;

/// Configures a UILabel as body text (body text style, label color).
+ (void)cm_configureBodyLabel:(UILabel *)label;

/// Configures a UILabel as a caption (caption1 text style, secondary label color).
+ (void)cm_configureCaptionLabel:(UILabel *)label;

#pragma mark - Button Configuration

/// Configures a UIButton with primary styling (filled, primary color).
+ (void)cm_configurePrimaryButton:(UIButton *)button;

/// Configures a UIButton with secondary/outline styling.
+ (void)cm_configureSecondaryButton:(UIButton *)button;

/// Configures a UIButton with destructive styling (error color).
+ (void)cm_configureDestructiveButton:(UIButton *)button;

#pragma mark - Text Field Configuration

/// Configures a UITextField with standard theming (border style, colors, Dynamic Type).
+ (void)cm_configureTextField:(UITextField *)textField
                  placeholder:(nullable NSString *)placeholder;

@end

NS_ASSUME_NONNULL_END
