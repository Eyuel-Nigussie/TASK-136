//
//  CMCameraCaptureViewController.h
//  CourierMatch
//
//  Camera capture for delivery proof photos and signatures.
//  Presents UIImagePickerController with source .camera, converts captured
//  image to JPEG, and saves via CMAttachmentService.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CMAttachment;

@protocol CMCameraCaptureDelegate <NSObject>
- (void)cameraCaptureDidCaptureAttachment:(CMAttachment *)attachment;
- (void)cameraCaptureDidCancel;
@end

@interface CMCameraCaptureViewController : UIViewController

@property (nonatomic, weak, nullable) id<CMCameraCaptureDelegate> delegate;

/// Initialize with the owner type and ID for the attachment record.
- (instancetype)initWithOwnerType:(NSString *)ownerType
                          ownerId:(NSString *)ownerId;

@end

NS_ASSUME_NONNULL_END
