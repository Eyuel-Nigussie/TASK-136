//
//  CMCameraCaptureViewController.m
//  CourierMatch
//

#import "CMCameraCaptureViewController.h"
#import "CMAttachment.h"
#import "CMAttachmentService.h"
#import "CMHaptics.h"
#import <AVFoundation/AVFoundation.h>

@interface CMCameraCaptureViewController ()
@property (nonatomic, copy) NSString *ownerType;
@property (nonatomic, copy) NSString *ownerId;
@end

@implementation CMCameraCaptureViewController

- (instancetype)initWithOwnerType:(NSString *)ownerType
                          ownerId:(NSString *)ownerId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _ownerType = [ownerType copy];
        _ownerId = [ownerId copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self checkCameraAndPresent];
}

#pragma mark - Camera Access

- (void)checkCameraAndPresent {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self showAlertWithTitle:@"Camera Unavailable"
                        message:@"This device does not have a camera."
                showSettings:NO];
        return;
    }

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            [self presentCamera];
            break;
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [self presentCamera];
                    } else {
                        [self showCameraPermissionDenied];
                    }
                });
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            [self showCameraPermissionDenied];
            break;
    }
}

- (void)presentCamera {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showCameraPermissionDenied {
    [self showAlertWithTitle:@"Camera Access Required"
                    message:@"Camera access is required to take photos. Please enable it in Settings."
               showSettings:YES];
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              showSettings:(BOOL)showSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    if (showSettings) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if (settingsURL && [[UIApplication sharedApplication] canOpenURL:settingsURL]) {
                [[UIApplication sharedApplication] openURL:settingsURL options:@{} completionHandler:nil];
            }
            [self dismissSelf];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissSelf];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissSelf {
    [self.delegate cameraCaptureDidCancel];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (!image) {
        [picker dismissViewControllerAnimated:YES completion:^{
            [self dismissSelf];
        }];
        return;
    }

    NSData *jpegData = UIImageJPEGRepresentation(image, 0.85);
    if (!jpegData) {
        [picker dismissViewControllerAnimated:YES completion:^{
            [self dismissSelf];
        }];
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"photo_%@.jpg", [[NSUUID UUID] UUIDString]];

    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [[CMAttachmentService shared] saveAttachmentWithFilename:filename
                                                            data:jpegData
                                                        mimeType:@"image/jpeg"
                                                       ownerType:weakSelf.ownerType
                                                         ownerId:weakSelf.ownerId
                                                      completion:^(CMAttachment *attachment, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (attachment) {
                    [CMHaptics success];
                    [weakSelf.delegate cameraCaptureDidCaptureAttachment:attachment];
                } else {
                    [CMHaptics error];
                }
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            });
        }];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        [self dismissSelf];
    }];
}

@end
