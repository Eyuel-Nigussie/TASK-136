//
//  UIView+CMAccessibility.h
//  CourierMatch
//
//  Category on UIView providing convenience methods for VoiceOver labelling
//  and minimum tap target enforcement per design.md §14.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (CMAccessibility)

/// Sets the accessibility label and hint in one call. If `hint` is nil only
/// the label is set.
- (void)cm_setAccessibilityLabel:(NSString *)label
                            hint:(nullable NSString *)hint;

/// Enforces a minimum 44x44pt tap target by expanding the view's intrinsic
/// content size constraints if needed. Call after Auto Layout is set up.
- (void)cm_enforceMinimumTapTarget;

/// Convenience: sets `isAccessibilityElement = YES`, assigns label/hint, and
/// enforces minimum tap target.
- (void)cm_configureAccessibilityWithLabel:(NSString *)label
                                      hint:(nullable NSString *)hint;

@end

NS_ASSUME_NONNULL_END
