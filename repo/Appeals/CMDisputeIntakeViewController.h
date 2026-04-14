//
//  CMDisputeIntakeViewController.h
//  CourierMatch
//
//  Form: order reference (pre-filled if pushed from order detail), reason text,
//  reason category picker, evidence attachment button.
//  Submit creates Dispute via CMDisputeRepository and emits dispute_opened notification.
//

#import <UIKit/UIKit.h>

@class CMOrder;

NS_ASSUME_NONNULL_BEGIN

@interface CMDisputeIntakeViewController : UIViewController

/// Optional pre-fill with order reference when pushed from order detail.
- (instancetype)initWithOrder:(nullable CMOrder *)order;

@end

NS_ASSUME_NONNULL_END
