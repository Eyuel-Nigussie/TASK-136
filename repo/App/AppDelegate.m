//
//  AppDelegate.m
//  CourierMatch
//
//  Step 2 wiring: boot Core Data off-main; broadcast memory pressure.
//  Step 10 wiring: register BGTaskScheduler tasks and schedule on launch.
//

#import "AppDelegate.h"
#import "CMCoreDataStack.h"
#import "CMBackgroundTaskManager.h"
#import "CMDebugLogger.h"
#import "CMError.h"

NSNotificationName const CMCoreDataDidBecomeReadyNotification = @"CMCoreDataDidBecomeReadyNotification";
NSNotificationName const CMMemoryPressureNotification         = @"CMMemoryPressureNotification";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ── Step 10: Register BGTaskScheduler tasks ──
    // Registration MUST happen before the end of didFinishLaunchingWithOptions
    // per Apple documentation. Handlers are invoked lazily by the system.
    [[CMBackgroundTaskManager shared] registerAllTasks];

    // Keep launch path minimal per design.md §13.1. Load Core Data on a
    // utility queue; the login screen tolerates a brief "loading" state
    // because session restore requires the stack anyway.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *err = nil;
        BOOL ok = [[CMCoreDataStack shared] loadStoresWithError:&err];
        if (!ok) {
            CMLogError(@"app", @"core data boot failed: %@", err);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CMCoreDataDidBecomeReadyNotification
                              object:@(ok)];

            // Schedule background tasks once Core Data is ready.
            if (ok) {
                [[CMBackgroundTaskManager shared] scheduleAllTasks];
            }
        });
    });
    return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                          sessionRole:connectingSceneSession.role];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[NSNotificationCenter defaultCenter] postNotificationName:CMMemoryPressureNotification
                                                        object:nil];
}

@end
