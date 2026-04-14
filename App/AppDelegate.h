//
//  AppDelegate.h
//  CourierMatch
//
//  Step 1 placeholder. The real delegate will:
//    - boot the Core Data stack (Persistence/CoreData) on a background queue
//    - register BGTaskScheduler identifiers (see Match/Attachments/Notifications/Audit)
//    - configure UIAppearance / theming (Common/Theming)
//    - broadcast CMMemoryPressureNotification on memory warnings
//  Wired incrementally in Steps 2, 6, 7, 9, and 10.
//

#import <UIKit/UIKit.h>

/// Posted on the main thread once `[CMCoreDataStack shared] loadStoresWithError:]`
/// completes. `object` is `@(YES)` on success, `@(NO)` on failure.
extern NSNotificationName const CMCoreDataDidBecomeReadyNotification;

/// Posted on main when the app receives a memory warning. Handlers (image
/// cache, fetch batch resizer) subscribe to flush their caches. See §13.2.
extern NSNotificationName const CMMemoryPressureNotification;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end
