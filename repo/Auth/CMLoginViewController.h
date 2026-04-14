//
//  CMLoginViewController.h
//  CourierMatch
//
//  Login screen per design.md §4. Supports:
//   - Tenant ID + username + password fields
//   - CAPTCHA display when CMAuthStepOutcomeCaptchaRequired
//   - Biometric login button when available
//   - Inline error display
//   - Haptic feedback on success/failure
//   - Dark Mode, Dynamic Type, VoiceOver, minimum tap targets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted when authentication succeeds and the caller should transition
/// to the main interface. `object` is the authenticated `CMUserAccount`.
extern NSNotificationName const CMLoginDidSucceedNotification;

@interface CMLoginViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
