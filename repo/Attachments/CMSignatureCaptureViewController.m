//
//  CMSignatureCaptureViewController.m
//  CourierMatch
//

#import "CMSignatureCaptureViewController.h"
#import "CMAttachmentService.h"
#import "CMAttachment.h"
#import "CMHaptics.h"
#import "CMDebugLogger.h"

#pragma mark - Signature Drawing View

@interface CMSignatureDrawingView : UIView
@property (nonatomic, strong) UIBezierPath *path;
@property (nonatomic, assign) BOOL hasContent;
@end

@implementation CMSignatureDrawingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.borderColor = [UIColor separatorColor].CGColor;
        self.layer.borderWidth = 1.0;
        self.layer.cornerRadius = 8;
        _path = [UIBezierPath bezierPath];
        _path.lineWidth = 2.5;
        _path.lineCapStyle = kCGLineCapRound;
        _path.lineJoinStyle = kCGLineJoinRound;
        _hasContent = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [[UIColor blackColor] setStroke];
    [self.path stroke];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    [self.path moveToPoint:[touch locationInView:self]];
    self.hasContent = YES;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    [self.path addLineToPoint:[touch locationInView:self]];
    [self setNeedsDisplay];
}

- (void)clear {
    self.path = [UIBezierPath bezierPath];
    self.path.lineWidth = 2.5;
    self.path.lineCapStyle = kCGLineCapRound;
    self.path.lineJoinStyle = kCGLineJoinRound;
    self.hasContent = NO;
    [self setNeedsDisplay];
}

- (UIImage *)captureImage {
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0.0);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

#pragma mark - Signature Capture VC

@interface CMSignatureCaptureViewController ()
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, strong) CMSignatureDrawingView *canvasView;
@property (nonatomic, strong) UILabel *instructionLabel;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *confirmButton;
@end

@implementation CMSignatureCaptureViewController

- (instancetype)initWithOrderId:(NSString *)orderId {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _orderId = [orderId copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Capture Signature";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                     target:self action:@selector(cancelTapped)];

    _instructionLabel = [[UILabel alloc] init];
    _instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _instructionLabel.text = @"Sign below to confirm delivery";
    _instructionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _instructionLabel.adjustsFontForContentSizeCategory = YES;
    _instructionLabel.textColor = [UIColor secondaryLabelColor];
    _instructionLabel.textAlignment = NSTextAlignmentCenter;
    _instructionLabel.accessibilityLabel = @"Sign below to confirm delivery";

    _canvasView = [[CMSignatureDrawingView alloc] init];
    _canvasView.translatesAutoresizingMaskIntoConstraints = NO;
    _canvasView.accessibilityLabel = @"Signature drawing area";
    _canvasView.isAccessibilityElement = YES;

    _clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _clearButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    _clearButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _clearButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _clearButton.accessibilityLabel = @"Clear signature";
    [_clearButton addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];

    _confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_confirmButton setTitle:@"Confirm Signature" forState:UIControlStateNormal];
    _confirmButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _confirmButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _confirmButton.backgroundColor = [UIColor systemBlueColor];
    [_confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _confirmButton.layer.cornerRadius = 10;
    _confirmButton.accessibilityLabel = @"Confirm signature";
    [_confirmButton addTarget:self action:@selector(confirmTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:_instructionLabel];
    [self.view addSubview:_canvasView];
    [self.view addSubview:_clearButton];
    [self.view addSubview:_confirmButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_instructionLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [_instructionLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_instructionLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],

        [_canvasView.topAnchor constraintEqualToAnchor:_instructionLabel.bottomAnchor constant:12],
        [_canvasView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_canvasView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_canvasView.heightAnchor constraintEqualToAnchor:_canvasView.widthAnchor multiplier:0.5],

        [_clearButton.topAnchor constraintEqualToAnchor:_canvasView.bottomAnchor constant:12],
        [_clearButton.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_clearButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        [_confirmButton.topAnchor constraintEqualToAnchor:_clearButton.bottomAnchor constant:20],
        [_confirmButton.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [_confirmButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [_confirmButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (void)cancelTapped {
    [self.delegate signatureCaptureDidCancel];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearTapped {
    [self.canvasView clear];
    [CMHaptics selectionChanged];
}

- (void)confirmTapped {
    if (!self.canvasView.hasContent) {
        [CMHaptics warning];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Signature"
                                                                      message:@"Please draw your signature before confirming."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIImage *image = [self.canvasView captureImage];
    NSData *pngData = UIImagePNGRepresentation(image);
    if (!pngData) {
        [CMHaptics error];
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"signature_%@.png", [[NSUUID UUID] UUIDString]];

    __weak typeof(self) weakSelf = self;
    [[CMAttachmentService shared] saveAttachmentWithFilename:filename
                                                        data:pngData
                                                    mimeType:@"image/png"
                                                   ownerType:@"signature"
                                                     ownerId:self.orderId
                                                  completion:^(CMAttachment *attachment, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (attachment) {
                [CMHaptics success];
                CMLogInfo(@"signature.capture", @"Signature captured for order %@",
                          [CMDebugLogger redact:weakSelf.orderId]);
                [weakSelf.delegate signatureCaptureDidComplete:attachment];
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            } else {
                [CMHaptics error];
            }
        });
    }];
}

@end
