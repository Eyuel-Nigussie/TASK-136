//
//  UIView+CMAccessibility.m
//  CourierMatch
//

#import "UIView+CMAccessibility.h"

static CGFloat const kCMMinimumTapTargetSize = 44.0;

@implementation UIView (CMAccessibility)

- (void)cm_setAccessibilityLabel:(NSString *)label
                            hint:(NSString *)hint {
    self.accessibilityLabel = label;
    if (hint) {
        self.accessibilityHint = hint;
    }
}

- (void)cm_enforceMinimumTapTarget {
    self.translatesAutoresizingMaskIntoConstraints = self.translatesAutoresizingMaskIntoConstraints; // preserve existing state
    NSLayoutConstraint *widthConstraint =
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:kCMMinimumTapTargetSize];
    widthConstraint.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *heightConstraint =
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:kCMMinimumTapTargetSize];
    heightConstraint.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[widthConstraint, heightConstraint]];
}

- (void)cm_configureAccessibilityWithLabel:(NSString *)label
                                      hint:(NSString *)hint {
    self.isAccessibilityElement = YES;
    [self cm_setAccessibilityLabel:label hint:hint];
    [self cm_enforceMinimumTapTarget];
}

@end
