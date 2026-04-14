//
//  CMDisputeIntakeViewController.m
//  CourierMatch
//

#import "CMDisputeIntakeViewController.h"
#import "CMOrder.h"
#import "CMDispute.h"
#import "CMDisputeService.h"
#import "CMNotificationCenterService.h"
#import "CMAttachmentService.h"
#import "CMCameraCaptureViewController.h"
#import "CMAttachment.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMHaptics.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSArray<NSString *> *CMDisputeReasonCategories(void) {
    return @[@"Damaged Package", @"Wrong Item", @"Missing Item", @"Late Delivery",
             @"Never Delivered", @"Billing Issue", @"Other"];
}

@interface CMDisputeIntakeViewController () <UIPickerViewDataSource, UIPickerViewDelegate,
                                             UIDocumentPickerDelegate,
                                             CMCameraCaptureDelegate>
@property (nonatomic, strong, nullable) CMOrder *order;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *formStack;
@property (nonatomic, strong) UITextField *orderRefField;
@property (nonatomic, strong) UITextView *reasonTextView;
@property (nonatomic, strong) UIPickerView *categoryPicker;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UILabel *attachmentStatusLabel;
@property (nonatomic, strong, nullable) NSData *attachedFileData;
@property (nonatomic, copy, nullable) NSString *attachedFilename;
@property (nonatomic, copy, nullable) NSString *attachedMimeType;
@property (nonatomic, strong, nullable) CMAttachment *cameraAttachment;
@property (nonatomic, assign) NSInteger selectedCategoryIndex;
@end

@implementation CMDisputeIntakeViewController

- (instancetype)initWithOrder:(CMOrder *)order {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _order = order;
        _selectedCategoryIndex = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Open Dispute";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupForm];
}

- (void)setupForm {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];

    // Order Reference
    UILabel *orderRefTitle = [self makeSectionLabel:@"Order Reference"];
    _orderRefField = [[UITextField alloc] init];
    _orderRefField.translatesAutoresizingMaskIntoConstraints = NO;
    _orderRefField.borderStyle = UITextBorderStyleRoundedRect;
    _orderRefField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _orderRefField.adjustsFontForContentSizeCategory = YES;
    _orderRefField.placeholder = @"Enter order reference";
    _orderRefField.accessibilityLabel = @"Order reference";
    _orderRefField.text = self.order.externalOrderRef ?: @"";
    if (self.order) {
        _orderRefField.enabled = NO;
        _orderRefField.textColor = [UIColor secondaryLabelColor];
    }

    // Reason
    UILabel *reasonTitle = [self makeSectionLabel:@"Reason"];
    _reasonTextView = [[UITextView alloc] init];
    _reasonTextView.translatesAutoresizingMaskIntoConstraints = NO;
    _reasonTextView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _reasonTextView.adjustsFontForContentSizeCategory = YES;
    _reasonTextView.layer.borderColor = [UIColor separatorColor].CGColor;
    _reasonTextView.layer.borderWidth = 1.0;
    _reasonTextView.layer.cornerRadius = 8;
    _reasonTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _reasonTextView.accessibilityLabel = @"Dispute reason";
    _reasonTextView.textColor = [UIColor labelColor];

    // Category Picker
    UILabel *categoryTitle = [self makeSectionLabel:@"Reason Category"];
    _categoryLabel = [[UILabel alloc] init];
    _categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _categoryLabel.adjustsFontForContentSizeCategory = YES;
    _categoryLabel.textColor = [UIColor labelColor];
    _categoryLabel.text = CMDisputeReasonCategories()[0];

    _categoryPicker = [[UIPickerView alloc] init];
    _categoryPicker.translatesAutoresizingMaskIntoConstraints = NO;
    _categoryPicker.dataSource = self;
    _categoryPicker.delegate = self;
    _categoryPicker.accessibilityLabel = @"Reason category picker";

    // Attachment
    _attachButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _attachButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_attachButton setTitle:@"Attach Evidence" forState:UIControlStateNormal];
    _attachButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _attachButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _attachButton.accessibilityLabel = @"Attach evidence file";
    _attachButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_attachButton addTarget:self action:@selector(attachTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [_attachButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    // Camera button
    _cameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cameraButton setTitle:@"Take Photo" forState:UIControlStateNormal];
    _cameraButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _cameraButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _cameraButton.accessibilityLabel = @"Take photo for evidence";
    _cameraButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_cameraButton addTarget:self action:@selector(cameraTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [_cameraButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    _attachmentStatusLabel = [[UILabel alloc] init];
    _attachmentStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _attachmentStatusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _attachmentStatusLabel.adjustsFontForContentSizeCategory = YES;
    _attachmentStatusLabel.textColor = [UIColor secondaryLabelColor];
    _attachmentStatusLabel.text = @"No file attached";

    // Submit
    _submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_submitButton setTitle:@"Submit Dispute" forState:UIControlStateNormal];
    _submitButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _submitButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _submitButton.backgroundColor = [UIColor systemBlueColor];
    [_submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _submitButton.layer.cornerRadius = 10;
    _submitButton.accessibilityLabel = @"Submit dispute";
    _submitButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_submitButton addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];

    _formStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        orderRefTitle, _orderRefField,
        reasonTitle, _reasonTextView,
        categoryTitle, _categoryPicker,
        _attachButton, _cameraButton, _attachmentStatusLabel,
        _submitButton
    ]];
    _formStack.translatesAutoresizingMaskIntoConstraints = NO;
    _formStack.axis = UILayoutConstraintAxisVertical;
    _formStack.spacing = 12;

    [_scrollView addSubview:_formStack];
    [NSLayoutConstraint activateConstraints:@[
        [_formStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:16],
        [_formStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [_formStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [_formStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-16],
        [_formStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-32],

        [_orderRefField.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [_reasonTextView.heightAnchor constraintGreaterThanOrEqualToConstant:120],
        [_categoryPicker.heightAnchor constraintEqualToConstant:120],
        [_submitButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (UILabel *)makeSectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

#pragma mark - Actions

- (void)attachTapped {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
                                              initForOpeningContentTypes:@[[UTType typeWithIdentifier:@"public.item"]]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)cameraTapped {
    CMCameraCaptureViewController *cameraVC = [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Dispute"
                                                                                              ownerId:@"pending"];
    cameraVC.delegate = self;
    [self presentViewController:cameraVC animated:YES completion:nil];
}

#pragma mark - CMCameraCaptureDelegate

- (void)cameraCaptureDidCaptureAttachment:(CMAttachment *)attachment {
    self.cameraAttachment = attachment;
    self.attachmentStatusLabel.text = [NSString stringWithFormat:@"Attached: %@", attachment.filename];
    [CMHaptics success];
}

- (void)cameraCaptureDidCancel {
    // No action needed
}

- (void)submitTapped {
    NSString *orderRef = self.orderRefField.text;
    NSString *reason = self.reasonTextView.text;
    NSString *category = CMDisputeReasonCategories()[self.selectedCategoryIndex];

    if (orderRef.length == 0) {
        [self showValidationError:@"Order reference is required."];
        return;
    }
    if (reason.length == 0) {
        [self showValidationError:@"Reason is required."];
        return;
    }

    // Create dispute via service layer (enforces role/auth/tenant checks).
    CMDisputeService *disputeService = [[CMDisputeService alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    NSError *serviceErr = nil;
    CMDispute *dispute = [disputeService openDisputeForOrder:self.order
                                                     orderId:orderRef
                                                      reason:reason
                                                    category:category
                                                       error:&serviceErr];
    if (!dispute) {
        [CMHaptics error];
        [self showValidationError:serviceErr.localizedDescription ?: @"Failed to open dispute."];
        return;
    }

    // Service already persisted the dispute to store.

    // Re-link camera-captured attachment from "pending" to real disputeId.
    if (self.cameraAttachment) {
        self.cameraAttachment.ownerId = dispute.disputeId;
        self.cameraAttachment.updatedAt = [NSDate date];
    }

    // If file-picker attachment present, save it with the detected MIME type.
    if (self.attachedFileData && self.attachedFilename && self.attachedMimeType) {
        [[CMAttachmentService shared] saveAttachmentWithFilename:self.attachedFilename
                                                            data:self.attachedFileData
                                                        mimeType:self.attachedMimeType
                                                       ownerType:@"Dispute"
                                                         ownerId:dispute.disputeId
                                                      completion:nil];
    }

    // Emit dispute_opened notification
    CMNotificationCenterService *notifService = [[CMNotificationCenterService alloc] init];
    NSString *recipientId = [CMTenantContext shared].currentUserId ?: @"";
    [notifService emitNotificationForEvent:@"dispute_opened"
                                   payload:@{@"orderRef": self.order.externalOrderRef ?: dispute.orderId,
                                             @"reason": reason}
                           recipientUserId:recipientId
                         subjectEntityType:@"Dispute"
                           subjectEntityId:dispute.disputeId
                                completion:nil];

    [CMHaptics success];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dispute Opened"
                                                                  message:@"Your dispute has been submitted successfully."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showValidationError:(NSString *)message {
    [CMHaptics warning];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Validation Error"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return (NSInteger)CMDisputeReasonCategories().count;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return CMDisputeReasonCategories()[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.selectedCategoryIndex = row;
    self.categoryLabel.text = CMDisputeReasonCategories()[row];
    [CMHaptics selectionChanged];
}

#pragma mark - UIDocumentPickerDelegate

- (nullable NSString *)mimeTypeForFileURL:(NSURL *)url {
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) {
        return @"image/jpeg";
    } else if ([ext isEqualToString:@"png"]) {
        return @"image/png";
    } else if ([ext isEqualToString:@"pdf"]) {
        return @"application/pdf";
    }
    return nil;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;

    NSString *mimeType = [self mimeTypeForFileURL:url];
    if (!mimeType) {
        [self showValidationError:@"Only JPG, PNG, and PDF files are supported"];
        return;
    }

    BOOL secured = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (secured) [url stopAccessingSecurityScopedResource];

    if (data) {
        self.attachedFileData = data;
        self.attachedFilename = url.lastPathComponent;
        self.attachedMimeType = mimeType;
        self.attachmentStatusLabel.text = [NSString stringWithFormat:@"Attached: %@", self.attachedFilename];
        [CMHaptics success];
    }
}

@end
