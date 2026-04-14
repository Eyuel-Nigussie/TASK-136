//
//  CMOrderDetailViewController.h
//  CourierMatch
//
//  Order detail: addresses, windows, parcel dimensions, status, assigned courier,
//  customer notes (masked by default), sensitive customer ID (masked).
//  Buttons: Assign (dispatcher), Update Status (courier), Open Dispute (CS).
//  Status changes write notifications via CMNotificationCenterService.
//

#import <UIKit/UIKit.h>

@class CMOrder;

NS_ASSUME_NONNULL_BEGIN

@interface CMOrderDetailViewController : UIViewController

- (instancetype)initWithOrder:(CMOrder *)order;

@end

NS_ASSUME_NONNULL_END
