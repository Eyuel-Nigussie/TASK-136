//
//  CMSignatureCaptureViewController.h
//  CourierMatch
//
//  Signature capture via drawing canvas. Produces a PNG attachment with
//  ownerType="signature" linked to the specified order.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CMAttachment;

@protocol CMSignatureCaptureDelegate <NSObject>
- (void)signatureCaptureDidComplete:(CMAttachment *)attachment;
- (void)signatureCaptureDidCancel;
@end

@interface CMSignatureCaptureViewController : UIViewController

@property (nonatomic, weak, nullable) id<CMSignatureCaptureDelegate> delegate;

/// Initialize with the order ID that the signature is linked to.
- (instancetype)initWithOrderId:(NSString *)orderId;

@end

NS_ASSUME_NONNULL_END
