//
//  SceneDelegate.h
//  CourierMatch
//
//  Scene delegate wiring per design.md §2.4 and Q20:
//   - Installs root view controller (login or main tab/split based on auth state)
//   - Per-window gesture recognizer for activity tracking (Q20)
//   - Scene lifecycle → CMSessionManager
//   - Session notification listeners to swap root on expire/force-logout
//   - iPad: UISplitViewController, iPhone: UITabBarController
//

#import <UIKit/UIKit.h>

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
