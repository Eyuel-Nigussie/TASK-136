//
//  CMSignupViewController.h
//  CourierMatch
//
//  Signup form per design.md §4.  Reusable form with:
//   - Tenant ID, username, password, confirm password, display name
//   - Role picker (from CMUserAccount role constants)
//   - Client-side CMPasswordPolicy validation before submission
//   - Connects to CMAuthService.signup
//   - Dark Mode, Dynamic Type, VoiceOver, minimum tap targets
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMSignupViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
