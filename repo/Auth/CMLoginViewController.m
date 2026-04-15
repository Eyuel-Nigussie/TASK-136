//
//  CMLoginViewController.m
//  CourierMatch
//

#import "CMLoginViewController.h"
#import "CMAuthService.h"
#import "CMBiometricAuth.h"
#import "CMBiometricEnrollment.h"
#import "CMCaptchaChallenge.h"
#import "CMUserAccount.h"
#import "CMSignupViewController.h"
#import "CMTheme.h"
#import "CMHaptics.h"
#import "UIView+CMAccessibility.h"

NSNotificationName const CMLoginDidSucceedNotification = @"CMLoginDidSucceedNotification";

@interface CMLoginViewController () <UITextFieldDelegate>

// Form fields
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *tenantIdField;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *biometricButton;
@property (nonatomic, strong) UIButton *signupButton;

// CAPTCHA section
@property (nonatomic, strong) UIView *captchaContainer;
@property (nonatomic, strong) UILabel *captchaQuestionLabel;
@property (nonatomic, strong) UITextField *captchaAnswerField;

// Error display
@property (nonatomic, strong) UILabel *errorLabel;

// Activity indicator
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

// State
@property (nonatomic, strong, nullable) CMCaptchaChallenge *pendingCaptcha;
@property (nonatomic, assign) BOOL isSubmitting;

@end

@implementation CMLoginViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [CMTheme cm_backgroundColor];
    [self buildUI];
    [self configureAccessibility];
    [self updateBiometricButtonVisibility];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tenantIdField becomeFirstResponder];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    // Re-evaluate appearance changes (dark/light) for layer borders.
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateAppearanceDependentLayers];
    }
}

#pragma mark - UI Construction

- (void)buildUI {
    // Scroll view for keyboard avoidance and long forms
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    // Title
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"CourierMatch";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [CMTheme cm_configureTitleLabel:self.titleLabel];
    [self.contentView addSubview:self.titleLabel];

    // Tenant ID
    self.tenantIdField = [self makeTextField:@"Tenant ID"];
    self.tenantIdField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tenantIdField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tenantIdField.returnKeyType = UIReturnKeyNext;
    [self.contentView addSubview:self.tenantIdField];

    // Username
    self.usernameField = [self makeTextField:@"Username"];
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.returnKeyType = UIReturnKeyNext;
    [self.contentView addSubview:self.usernameField];

    // Password
    self.passwordField = [self makeTextField:@"Password"];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    [self.contentView addSubview:self.passwordField];

    // CAPTCHA container (hidden by default)
    self.captchaContainer = [[UIView alloc] init];
    self.captchaContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.captchaContainer.hidden = YES;
    [self.contentView addSubview:self.captchaContainer];

    self.captchaQuestionLabel = [[UILabel alloc] init];
    self.captchaQuestionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.captchaQuestionLabel.textAlignment = NSTextAlignmentCenter;
    [CMTheme cm_configureLabel:self.captchaQuestionLabel
                     textStyle:UIFontTextStyleTitle2
                         color:[CMTheme cm_warningColor]];
    [self.captchaContainer addSubview:self.captchaQuestionLabel];

    self.captchaAnswerField = [self makeTextField:@"CAPTCHA Answer"];
    self.captchaAnswerField.keyboardType = UIKeyboardTypeNumberPad;
    self.captchaAnswerField.returnKeyType = UIReturnKeyGo;
    self.captchaAnswerField.textAlignment = NSTextAlignmentCenter;
    [self.captchaContainer addSubview:self.captchaAnswerField];

    // CAPTCHA container internal layout
    [NSLayoutConstraint activateConstraints:@[
        [self.captchaQuestionLabel.topAnchor constraintEqualToAnchor:self.captchaContainer.topAnchor constant:8],
        [self.captchaQuestionLabel.leadingAnchor constraintEqualToAnchor:self.captchaContainer.leadingAnchor],
        [self.captchaQuestionLabel.trailingAnchor constraintEqualToAnchor:self.captchaContainer.trailingAnchor],

        [self.captchaAnswerField.topAnchor constraintEqualToAnchor:self.captchaQuestionLabel.bottomAnchor constant:8],
        [self.captchaAnswerField.leadingAnchor constraintEqualToAnchor:self.captchaContainer.leadingAnchor],
        [self.captchaAnswerField.trailingAnchor constraintEqualToAnchor:self.captchaContainer.trailingAnchor],
        [self.captchaAnswerField.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [self.captchaAnswerField.bottomAnchor constraintEqualToAnchor:self.captchaContainer.bottomAnchor],
    ]];

    // Error label
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    [CMTheme cm_configureLabel:self.errorLabel
                     textStyle:UIFontTextStyleFootnote
                         color:[CMTheme cm_errorColor]];
    self.errorLabel.hidden = YES;
    [self.contentView addSubview:self.errorLabel];

    // Login button
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loginButton setTitle:@"Sign In" forState:UIControlStateNormal];
    [CMTheme cm_configurePrimaryButton:self.loginButton];
    [self.loginButton addTarget:self action:@selector(loginTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.loginButton];

    // Biometric button
    self.biometricButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.biometricButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.biometricButton setTitle:@"Sign In with Biometrics" forState:UIControlStateNormal];
    [CMTheme cm_configureSecondaryButton:self.biometricButton];
    [self.biometricButton addTarget:self action:@selector(biometricTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.biometricButton.hidden = YES;
    [self.contentView addSubview:self.biometricButton];

    // Signup button
    self.signupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.signupButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.signupButton setTitle:@"Create Account" forState:UIControlStateNormal];
    [self.signupButton setTitleColor:[CMTheme cm_primaryColor] forState:UIControlStateNormal];
    self.signupButton.titleLabel.font = [CMTheme cm_fontForTextStyle:UIFontTextStyleSubheadline];
    self.signupButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.signupButton addTarget:self action:@selector(signupTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.signupButton];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;
    [self.contentView addSubview:self.spinner];

    [self applyConstraints];
    [self registerForKeyboardNotifications];
}

- (UITextField *)makeTextField:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.delegate = self;
    [CMTheme cm_configureTextField:field placeholder:placeholder];
    return field;
}

- (void)applyConstraints {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide *readable = self.view.readableContentGuide;

    [NSLayoutConstraint activateConstraints:@[
        // Scroll view fills safe area
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Content view inside scroll
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],

        // Content view width matches readable content guide for proper margins
        [self.contentView.leadingAnchor constraintGreaterThanOrEqualToAnchor:readable.leadingAnchor],
        [self.contentView.trailingAnchor constraintLessThanOrEqualToAnchor:readable.trailingAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:48],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Tenant ID field
        [self.tenantIdField.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:40],
        [self.tenantIdField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.tenantIdField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.tenantIdField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Username field
        [self.usernameField.topAnchor constraintEqualToAnchor:self.tenantIdField.bottomAnchor constant:16],
        [self.usernameField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.usernameField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.usernameField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Password field
        [self.passwordField.topAnchor constraintEqualToAnchor:self.usernameField.bottomAnchor constant:16],
        [self.passwordField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.passwordField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.passwordField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // CAPTCHA container
        [self.captchaContainer.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:16],
        [self.captchaContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.captchaContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Error label
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.captchaContainer.bottomAnchor constant:12],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Login button
        [self.loginButton.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:20],
        [self.loginButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.loginButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.loginButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Biometric button
        [self.biometricButton.topAnchor constraintEqualToAnchor:self.loginButton.bottomAnchor constant:12],
        [self.biometricButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.biometricButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.biometricButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Signup button
        [self.signupButton.topAnchor constraintEqualToAnchor:self.biometricButton.bottomAnchor constant:24],
        [self.signupButton.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.signupButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Spinner
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.signupButton.bottomAnchor constant:16],

        // Bottom of content
        [self.spinner.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-24],
    ]];
}

#pragma mark - Accessibility

- (void)configureAccessibility {
    [self.tenantIdField cm_configureAccessibilityWithLabel:@"Tenant ID" hint:@"Enter your organization tenant identifier"];
    [self.usernameField cm_configureAccessibilityWithLabel:@"Username" hint:@"Enter your username"];
    [self.passwordField cm_configureAccessibilityWithLabel:@"Password" hint:@"Enter your password"];
    [self.captchaAnswerField cm_configureAccessibilityWithLabel:@"CAPTCHA Answer" hint:@"Enter the answer to the arithmetic question"];
    [self.loginButton cm_configureAccessibilityWithLabel:@"Sign In" hint:@"Double tap to sign in"];
    [self.biometricButton cm_configureAccessibilityWithLabel:@"Sign In with Biometrics" hint:@"Double tap to sign in using Face ID or Touch ID"];
    [self.signupButton cm_configureAccessibilityWithLabel:@"Create Account" hint:@"Double tap to create a new account"];
}

#pragma mark - Biometric Visibility

- (void)updateBiometricButtonVisibility {
    BOOL available = [CMBiometricAuth isAvailable];
    self.biometricButton.hidden = !available;
}

#pragma mark - Appearance

- (void)updateAppearanceDependentLayers {
    // Re-apply border color for secondary button since CGColor doesn't auto-adapt
    self.biometricButton.layer.borderColor = [CMTheme cm_primaryColor].CGColor;
}

#pragma mark - Actions

- (void)loginTapped:(UIButton *)sender {
    [self.view endEditing:YES];

    NSString *tenantId = [self.tenantIdField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *username = [self.usernameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text ?: @"";

    // Basic client-side validation
    if (tenantId.length == 0 || username.length == 0 || password.length == 0) {
        [self showError:@"All fields are required"];
        [CMHaptics warning];
        return;
    }

    NSString *captchaId = self.pendingCaptcha.challengeId;
    NSString *captchaAnswer = nil;
    if (self.pendingCaptcha) {
        captchaAnswer = [self.captchaAnswerField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (captchaAnswer.length == 0) {
            [self showError:@"Please answer the CAPTCHA question"];
            [CMHaptics warning];
            return;
        }
    }

    [self setSubmitting:YES];

    __weak typeof(self) weakSelf = self;
    [[CMAuthService shared] loginWithTenantId:tenantId
                                     username:username
                                     password:password
                            captchaChallengeId:captchaId
                                 captchaAnswer:captchaAnswer
                                    completion:^(CMAuthAttemptResult *result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self setSubmitting:NO];
        [self handleAuthResult:result];
    }];
}

- (void)biometricTapped:(UIButton *)sender {
    [self.view endEditing:YES];

    // Biometric login requires a previously authenticated account binding.
    // Both userId and tenantId are stored from the last successful password login
    // and are verified for consistency before proceeding.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *userId = [defaults stringForKey:@"CMLastAuthenticatedUserId"];
    NSString *lastTenantId = [defaults stringForKey:@"CMLastAuthenticatedTenantId"];

    if (!userId || userId.length == 0 || !lastTenantId || lastTenantId.length == 0) {
        [self showError:@"Please sign in with your password first to enable biometric login"];
        [CMHaptics warning];
        return;
    }

    // If user filled in a tenantId field, verify it matches the stored binding.
    NSString *enteredTenantId = [self.tenantIdField.text stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (enteredTenantId.length > 0 && ![enteredTenantId isEqualToString:lastTenantId]) {
        [self showError:[NSString stringWithFormat:
                         @"Biometric login is bound to a different tenant. Please sign in with password for '%@'.",
                         enteredTenantId]];
        [CMHaptics warning];
        return;
    }

    [self setSubmitting:YES];

    __weak typeof(self) weakSelf = self;
    [[CMAuthService shared] loginWithBiometricsForUserId:userId
                                              completion:^(CMAuthAttemptResult *result) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self setSubmitting:NO];
        [self handleAuthResult:result];
    }];
}

- (void)signupTapped:(UIButton *)sender {
    // MVP: the "Create Account" button from the login screen always creates
    // courier accounts (no role choice). The signup view controller enforces
    // this by checking CMTenantContext — since no user is logged in here,
    // the role picker is automatically hidden and defaults to "courier".
    CMSignupViewController *vc = [[CMSignupViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Auth Result Handling

- (void)handleAuthResult:(CMAuthAttemptResult *)result {
    switch (result.outcome) {
        case CMAuthStepOutcomeSucceeded: {
            [CMHaptics success];
            [self hideError];
            [self hideCaptcha];
            self.pendingCaptcha = nil;
            // Persist userId + tenantId for future biometric login binding
            if (result.user.userId) {
                [[NSUserDefaults standardUserDefaults] setObject:result.user.userId
                                                         forKey:@"CMLastAuthenticatedUserId"];
                [[NSUserDefaults standardUserDefaults] setObject:result.user.tenantId ?: @""
                                                         forKey:@"CMLastAuthenticatedTenantId"];
            }
            // Offer biometric enrollment if available and not yet enrolled
            if ([CMBiometricAuth isAvailable] && !result.user.biometricEnabled) {
                [self promptBiometricEnrollmentForUser:result.user];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:CMLoginDidSucceedNotification
                                                                    object:result.user];
            }
            break;
        }

        case CMAuthStepOutcomeFailed: {
            [CMHaptics error];
            NSString *msg = result.error.localizedDescription ?: @"Invalid credentials";
            [self showError:msg];
            break;
        }

        case CMAuthStepOutcomeLocked: {
            [CMHaptics error];
            NSString *msg = result.error.localizedDescription ?: @"Account is temporarily locked. Please try again later.";
            [self showError:msg];
            [self hideCaptcha];
            self.pendingCaptcha = nil;
            break;
        }

        case CMAuthStepOutcomeCaptchaRequired: {
            [CMHaptics warning];
            self.pendingCaptcha = result.pendingCaptcha;
            [self showCaptchaWithQuestion:result.pendingCaptcha.question];
            [self showError:result.error.localizedDescription ?: @"Please solve the CAPTCHA to continue"];
            break;
        }

        case CMAuthStepOutcomeCaptchaFailed: {
            [CMHaptics error];
            // A new captcha is issued on failure; update the displayed question
            self.pendingCaptcha = result.pendingCaptcha;
            [self showCaptchaWithQuestion:result.pendingCaptcha.question];
            self.captchaAnswerField.text = @"";
            [self showError:result.error.localizedDescription ?: @"CAPTCHA answer was incorrect. Try again."];
            break;
        }

        case CMAuthStepOutcomePasswordPolicy: {
            [CMHaptics warning];
            [self showError:result.error.localizedDescription ?: @"Password does not meet policy requirements"];
            break;
        }
    }
}

#pragma mark - Biometric Enrollment Prompt

- (void)promptBiometricEnrollmentForUser:(CMUserAccount *)user {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enable Face ID/Touch ID"
                                                                  message:@"Enable Face ID/Touch ID for faster sign-in?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [CMBiometricEnrollment enrollBiometricsForUser:user completion:^(BOOL success, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (success) {
                [CMHaptics success];
            }
            // Proceed to main interface regardless of enrollment outcome
            [[NSNotificationCenter defaultCenter] postNotificationName:CMLoginDidSucceedNotification
                                                                object:user];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Not Now" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CMLoginDidSucceedNotification
                                                            object:user];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CAPTCHA

- (void)showCaptchaWithQuestion:(NSString *)question {
    self.captchaQuestionLabel.text = [NSString stringWithFormat:@"Solve: %@", question ?: @"?"];
    self.captchaContainer.hidden = NO;
    self.captchaQuestionLabel.accessibilityLabel = [NSString stringWithFormat:@"CAPTCHA question: %@", question ?: @"unknown"];
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
    [self.captchaAnswerField becomeFirstResponder];
}

- (void)hideCaptcha {
    self.captchaContainer.hidden = YES;
    self.captchaAnswerField.text = @"";
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - Error Display

- (void)showError:(NSString *)message {
    self.errorLabel.text = message;
    self.errorLabel.hidden = NO;
    // Announce error for VoiceOver
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

- (void)hideError {
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
}

#pragma mark - Submitting State

- (void)setSubmitting:(BOOL)submitting {
    _isSubmitting = submitting;
    self.loginButton.enabled = !submitting;
    self.biometricButton.enabled = !submitting;
    self.signupButton.enabled = !submitting;
    self.loginButton.alpha = submitting ? 0.6 : 1.0;

    if (submitting) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.tenantIdField) {
        [self.usernameField becomeFirstResponder];
    } else if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
    } else if (textField == self.passwordField) {
        if (self.pendingCaptcha && !self.captchaContainer.hidden) {
            [self.captchaAnswerField becomeFirstResponder];
        } else {
            [self loginTapped:self.loginButton];
        }
    } else if (textField == self.captchaAnswerField) {
        [self loginTapped:self.loginButton];
    }
    return YES;
}

#pragma mark - Keyboard Handling

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect kbInView = [self.view convertRect:kbFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.scrollView.frame) - CGRectGetMinY(kbInView);
    if (overlap > 0) {
        NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        [UIView animateWithDuration:duration animations:^{
            self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, overlap + 20, 0);
            self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset;
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
