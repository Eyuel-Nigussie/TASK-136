//
//  CMAdminDashboardViewController.h
//  CourierMatch
//
//  Role-gated admin screen. Sections: User Management (list users, change roles),
//  Diagnostics (debug log viewer with share-sheet export),
//  Forced Logout (select user -> set forceLogoutAt).
//  Permission changes go through CMPermissionChangeAuditor.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMAdminDashboardViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
