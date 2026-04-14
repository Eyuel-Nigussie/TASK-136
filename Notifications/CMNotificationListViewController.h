//
//  CMNotificationListViewController.h
//  CourierMatch
//
//  In-app notification center. Unread badge on tab. Each row shows
//  rendered title/body, timestamp, read/unread indicator, ack button for dispatchers.
//  Tap marks read. Digest rows show child count.
//  Uses CMNotificationCenterService.
//  Listens for CMNotificationUnreadCountDidChangeNotification.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMNotificationListViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
