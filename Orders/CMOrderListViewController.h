//
//  CMOrderListViewController.h
//  CourierMatch
//
//  Filterable order list with segment control: New / Assigned / Delivered / All.
//  Each row shows externalOrderRef, pickup -> dropoff summary, status badge,
//  time window. Tap pushes detail.
//  Uses CMOrderRepository.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMOrderListViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
