//
//  CMTheme.m
//  CourierMatch
//

#import "CMTheme.h"

@implementation CMTheme

#pragma mark - Semantic Colors

+ (UIColor *)cm_primaryColor {
    return [UIColor systemBlueColor];
}

+ (UIColor *)cm_errorColor {
    return [UIColor systemRedColor];
}

+ (UIColor *)cm_successColor {
    return [UIColor systemGreenColor];
}

+ (UIColor *)cm_warningColor {
    return [UIColor systemOrangeColor];
}

+ (UIColor *)cm_backgroundColor {
    return [UIColor systemBackgroundColor];
}

+ (UIColor *)cm_secondaryBackgroundColor {
    return [UIColor secondarySystemBackgroundColor];
}

+ (UIColor *)cm_groupedBackgroundColor {
    return [UIColor systemGroupedBackgroundColor];
}

+ (UIColor *)cm_labelColor {
    return [UIColor labelColor];
}

+ (UIColor *)cm_secondaryLabelColor {
    return [UIColor secondaryLabelColor];
}

+ (UIColor *)cm_tertiaryLabelColor {
    return [UIColor tertiaryLabelColor];
}

+ (UIColor *)cm_separatorColor {
    return [UIColor separatorColor];
}

+ (UIColor *)cm_fieldBackgroundColor {
    return [UIColor tertiarySystemFillColor];
}

#pragma mark - Text Style Fonts

+ (UIFont *)cm_fontForTextStyle:(UIFontTextStyle)style {
    return [UIFont preferredFontForTextStyle:style];
}

+ (UIFont *)cm_boldFontForTextStyle:(UIFontTextStyle)style {
    UIFontDescriptor *desc = [UIFontDescriptor preferredFontDescriptorWithTextStyle:style];
    UIFontDescriptor *boldDesc = [desc fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    if (!boldDesc) {
        boldDesc = desc;
    }
    return [UIFont fontWithDescriptor:boldDesc size:0];
}

#pragma mark - Label Configuration

+ (void)cm_configureLabel:(UILabel *)label
                textStyle:(UIFontTextStyle)style
                    color:(UIColor *)color {
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    label.numberOfLines = 0;
}

+ (void)cm_configureTitleLabel:(UILabel *)label {
    [self cm_configureLabel:label
                  textStyle:UIFontTextStyleLargeTitle
                      color:[self cm_labelColor]];
}

+ (void)cm_configureBodyLabel:(UILabel *)label {
    [self cm_configureLabel:label
                  textStyle:UIFontTextStyleBody
                      color:[self cm_labelColor]];
}

+ (void)cm_configureCaptionLabel:(UILabel *)label {
    [self cm_configureLabel:label
                  textStyle:UIFontTextStyleCaption1
                      color:[self cm_secondaryLabelColor]];
}

#pragma mark - Button Configuration

+ (void)cm_configurePrimaryButton:(UIButton *)button {
    button.backgroundColor = [self cm_primaryColor];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [self cm_boldFontForTextStyle:UIFontTextStyleBody];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.layer.cornerRadius = 10.0;
    button.layer.masksToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 24, 12, 24);
}

+ (void)cm_configureSecondaryButton:(UIButton *)button {
    button.backgroundColor = [UIColor clearColor];
    [button setTitleColor:[self cm_primaryColor] forState:UIControlStateNormal];
    button.titleLabel.font = [self cm_boldFontForTextStyle:UIFontTextStyleBody];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.layer.cornerRadius = 10.0;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [self cm_primaryColor].CGColor;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 24, 12, 24);
}

+ (void)cm_configureDestructiveButton:(UIButton *)button {
    button.backgroundColor = [self cm_errorColor];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [self cm_boldFontForTextStyle:UIFontTextStyleBody];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.layer.cornerRadius = 10.0;
    button.layer.masksToBounds = YES;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 24, 12, 24);
}

#pragma mark - Text Field Configuration

+ (void)cm_configureTextField:(UITextField *)textField
                  placeholder:(NSString *)placeholder {
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.backgroundColor = [self cm_fieldBackgroundColor];
    textField.textColor = [self cm_labelColor];
    textField.font = [self cm_fontForTextStyle:UIFontTextStyleBody];
    textField.adjustsFontForContentSizeCategory = YES;
    if (placeholder) {
        textField.attributedPlaceholder =
            [[NSAttributedString alloc] initWithString:placeholder
                                            attributes:@{
                NSForegroundColorAttributeName: [self cm_tertiaryLabelColor],
                NSFontAttributeName: [self cm_fontForTextStyle:UIFontTextStyleBody]
            }];
    }
}

@end
