//
//  CMHaptics.h
//  CourierMatch
//
//  Named haptic feedback methods per design.md §14.
//  Uses UIFeedbackGenerator subclasses. Safe to call on devices without
//  a Taptic Engine — the system silently no-ops.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMHaptics : NSObject

/// Medium-impact haptic for successful actions (login, save, finalize).
+ (void)success;

/// Error-pattern haptic for failures (login failure, validation error).
+ (void)error;

/// Warning-pattern haptic for caution states (lock, CAPTCHA).
+ (void)warning;

/// Light selection haptic for picker/tab changes.
+ (void)selectionChanged;

@end

NS_ASSUME_NONNULL_END
