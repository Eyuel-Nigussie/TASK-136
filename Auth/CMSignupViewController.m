//
//  CMSignupViewController.m
//  CourierMatch
//

#import "CMSignupViewController.h"
#import "CMAuthService.h"
#import "CMPasswordPolicy.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"
#import "CMTheme.h"
#import "CMHaptics.h"
#import "UIView+CMAccessibility.h"

/// Available roles for the role picker.
static NSArray<NSString *> *CMSignupAvailableRoles(void) {
    return @[
        CMUserRoleCourier,
        CMUserRoleDispatcher,
        CMUserRoleReviewer,
        CMUserRoleCustomerService,
        CMUserRoleFinance,
        CMUserRoleAdmin,
    ];
}

/// Human-readable display names for roles.
static NSString *CMSignupRoleDisplayName(NSString *role) {
    if ([role isEqualToString:CMUserRoleCourier])         return @"Courier";
    if ([role isEqualToString:CMUserRoleDispatcher])      return @"Dispatcher";
    if ([role isEqualToString:CMUserRoleReviewer])        return @"Reviewer";
    if ([role isEqualToString:CMUserRoleCustomerService]) return @"Customer Service";
    if ([role isEqualToString:CMUserRoleFinance])         return @"Finance";
    if ([role isEqualToString:CMUserRoleAdmin])           return @"Admin";
    return role;
}

@interface CMSignupViewController () <UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *tenantIdField;
@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *confirmPasswordField;
@property (nonatomic, strong) UITextField *displayNameField;
@property (nonatomic, strong) UITextField *roleField;
@property (nonatomic, strong) UIPickerView *rolePicker;
@property (nonatomic, strong) UIButton *signupButton;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *passwordPolicyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) NSArray<NSString *> *roles;
@property (nonatomic, assign) NSInteger selectedRoleIndex;
@property (nonatomic, assign) BOOL isSubmitting;

@end

@implementation CMSignupViewController

#pragma mark - Lifecycle

- (BOOL)isAdminCreatingAccount {
    CMTenantContext *tc = [CMTenantContext shared];
    return tc.isAuthenticated && [tc.currentRole isEqualToString:CMUserRoleAdmin];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [CMTheme cm_backgroundColor];
    self.title = @"Create Account";

    // Security: only an authenticated admin may choose a role.
    // Self-service signup is restricted to the courier role.
    if ([self isAdminCreatingAccount]) {
        self.roles = CMSignupAvailableRoles();
    } else {
        self.roles = @[CMUserRoleCourier];
    }
    self.selectedRoleIndex = 0;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                     target:self
                                                     action:@selector(cancelTapped:)];
    [self buildUI];
    [self configureAccessibility];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self updateAppearanceDependentLayers];
    }
}

#pragma mark - UI Construction

- (void)buildUI {
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
    self.titleLabel.text = @"New Account";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [CMTheme cm_configureLabel:self.titleLabel
                     textStyle:UIFontTextStyleTitle1
                         color:[CMTheme cm_labelColor]];
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

    // Display Name
    self.displayNameField = [self makeTextField:@"Display Name (optional)"];
    self.displayNameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.displayNameField.returnKeyType = UIReturnKeyNext;
    [self.contentView addSubview:self.displayNameField];

    // Password
    self.passwordField = [self makeTextField:@"Password"];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.returnKeyType = UIReturnKeyNext;
    [self.contentView addSubview:self.passwordField];

    // Confirm Password
    self.confirmPasswordField = [self makeTextField:@"Confirm Password"];
    self.confirmPasswordField.secureTextEntry = YES;
    self.confirmPasswordField.returnKeyType = UIReturnKeyNext;
    [self.contentView addSubview:self.confirmPasswordField];

    // Password policy hint
    self.passwordPolicyLabel = [[UILabel alloc] init];
    self.passwordPolicyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.passwordPolicyLabel.text = @"Min 12 characters, at least 1 digit and 1 symbol";
    [CMTheme cm_configureCaptionLabel:self.passwordPolicyLabel];
    self.passwordPolicyLabel.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:self.passwordPolicyLabel];

    // Role picker field — only shown when an admin is creating accounts.
    // Self-service signup is locked to the courier role.
    BOOL showRolePicker = [self isAdminCreatingAccount];
    self.roleField = [self makeTextField:@"Role"];
    self.roleField.text = CMSignupRoleDisplayName(self.roles[0]);
    if (showRolePicker) {
        [self.contentView addSubview:self.roleField];

        // UIPickerView as inputView for role field
        self.rolePicker = [[UIPickerView alloc] init];
        self.rolePicker.delegate = self;
        self.rolePicker.dataSource = self;
        self.roleField.inputView = self.rolePicker;

        // Toolbar for picker
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
        toolbar.barStyle = UIBarStyleDefault;
        UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                              target:nil
                                                                              action:nil];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(rolePickerDone:)];
        toolbar.items = @[flex, done];
        self.roleField.inputAccessoryView = toolbar;
    }

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

    // Signup button
    self.signupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.signupButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.signupButton setTitle:@"Create Account" forState:UIControlStateNormal];
    [CMTheme cm_configurePrimaryButton:self.signupButton];
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
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.contentView.leadingAnchor constraintGreaterThanOrEqualToAnchor:readable.leadingAnchor],
        [self.contentView.trailingAnchor constraintLessThanOrEqualToAnchor:readable.trailingAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        // Title
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:24],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Tenant ID
        [self.tenantIdField.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:24],
        [self.tenantIdField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.tenantIdField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.tenantIdField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Username
        [self.usernameField.topAnchor constraintEqualToAnchor:self.tenantIdField.bottomAnchor constant:16],
        [self.usernameField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.usernameField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.usernameField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Display Name
        [self.displayNameField.topAnchor constraintEqualToAnchor:self.usernameField.bottomAnchor constant:16],
        [self.displayNameField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.displayNameField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.displayNameField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Password
        [self.passwordField.topAnchor constraintEqualToAnchor:self.displayNameField.bottomAnchor constant:16],
        [self.passwordField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.passwordField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.passwordField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Confirm Password
        [self.confirmPasswordField.topAnchor constraintEqualToAnchor:self.passwordField.bottomAnchor constant:16],
        [self.confirmPasswordField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.confirmPasswordField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.confirmPasswordField.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Password policy hint
        [self.passwordPolicyLabel.topAnchor constraintEqualToAnchor:self.confirmPasswordField.bottomAnchor constant:4],
        [self.passwordPolicyLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.passwordPolicyLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Error label
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],

        // Signup button
        [self.signupButton.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:20],
        [self.signupButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
        [self.signupButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
        [self.signupButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        // Spinner
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.spinner.topAnchor constraintEqualToAnchor:self.signupButton.bottomAnchor constant:16],
        [self.spinner.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-24],
    ]];

    // Conditional role-field and error-label top anchor based on admin status.
    if ([self isAdminCreatingAccount]) {
        [NSLayoutConstraint activateConstraints:@[
            [self.roleField.topAnchor constraintEqualToAnchor:self.passwordPolicyLabel.bottomAnchor constant:16],
            [self.roleField.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:24],
            [self.roleField.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-24],
            [self.roleField.heightAnchor constraintGreaterThanOrEqualToConstant:44],
            [self.errorLabel.topAnchor constraintEqualToAnchor:self.roleField.bottomAnchor constant:12],
        ]];
    } else {
        // No role picker — error label follows the password policy label directly.
        [NSLayoutConstraint activateConstraints:@[
            [self.errorLabel.topAnchor constraintEqualToAnchor:self.passwordPolicyLabel.bottomAnchor constant:12],
        ]];
    }
}

#pragma mark - Accessibility

- (void)configureAccessibility {
    [self.tenantIdField cm_configureAccessibilityWithLabel:@"Tenant ID" hint:@"Enter your organization tenant identifier"];
    [self.usernameField cm_configureAccessibilityWithLabel:@"Username" hint:@"Choose a username"];
    [self.displayNameField cm_configureAccessibilityWithLabel:@"Display Name" hint:@"Enter your display name, optional"];
    [self.passwordField cm_configureAccessibilityWithLabel:@"Password" hint:@"Choose a password, minimum 12 characters with a digit and symbol"];
    [self.confirmPasswordField cm_configureAccessibilityWithLabel:@"Confirm Password" hint:@"Re-enter your password"];
    [self.roleField cm_configureAccessibilityWithLabel:@"Role" hint:@"Select your account role"];
    [self.signupButton cm_configureAccessibilityWithLabel:@"Create Account" hint:@"Double tap to create your account"];
}

- (void)updateAppearanceDependentLayers {
    // No secondary buttons needing layer color updates in this controller
}

#pragma mark - Actions

- (void)cancelTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)rolePickerDone:(id)sender {
    [self.roleField resignFirstResponder];
}

- (void)signupTapped:(UIButton *)sender {
    [self.view endEditing:YES];

    NSString *tenantId = [self.tenantIdField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *username = [self.usernameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *displayName = [self.displayNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text ?: @"";
    NSString *confirmPassword = self.confirmPasswordField.text ?: @"";

    // Basic validation
    if (tenantId.length == 0 || username.length == 0) {
        [self showError:@"Tenant ID and username are required"];
        [CMHaptics warning];
        return;
    }

    if (password.length == 0) {
        [self showError:@"Password is required"];
        [CMHaptics warning];
        return;
    }

    if (![password isEqualToString:confirmPassword]) {
        [self showError:@"Passwords do not match"];
        [CMHaptics warning];
        return;
    }

    // Client-side password policy check
    CMPasswordViolation violations = [[CMPasswordPolicy shared] evaluate:password];
    if (violations != CMPasswordViolationNone) {
        NSString *summary = [[CMPasswordPolicy shared] summaryForViolations:violations];
        [self showError:summary];
        [CMHaptics warning];
        return;
    }

    NSString *role = self.roles[self.selectedRoleIndex];

    [self setSubmitting:YES];

    __weak typeof(self) weakSelf = self;
    [[CMAuthService shared] signupWithTenantId:tenantId
                                      username:username
                                      password:password
                                   displayName:(displayName.length > 0 ? displayName : nil)
                                          role:role
                                    completion:^(CMUserAccount * _Nullable user, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [self setSubmitting:NO];

        if (error) {
            [CMHaptics error];
            [self showError:error.localizedDescription ?: @"Account creation failed"];
            return;
        }

        [CMHaptics success];
        [self hideError];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Account Created"
                                                                       message:[NSString stringWithFormat:@"Account for '%@' has been created. You can now sign in.", user.username ?: username]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

#pragma mark - Error Display

- (void)showError:(NSString *)message {
    self.errorLabel.text = message;
    self.errorLabel.hidden = NO;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

- (void)hideError {
    self.errorLabel.text = nil;
    self.errorLabel.hidden = YES;
}

#pragma mark - Submitting State

- (void)setSubmitting:(BOOL)submitting {
    _isSubmitting = submitting;
    self.signupButton.enabled = !submitting;
    self.signupButton.alpha = submitting ? 0.6 : 1.0;
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
        [self.displayNameField becomeFirstResponder];
    } else if (textField == self.displayNameField) {
        [self.passwordField becomeFirstResponder];
    } else if (textField == self.passwordField) {
        [self.confirmPasswordField becomeFirstResponder];
    } else if (textField == self.confirmPasswordField) {
        if ([self isAdminCreatingAccount]) {
            [self.roleField becomeFirstResponder];
        } else {
            [self signupTapped:self.signupButton];
        }
    }
    return YES;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return (NSInteger)self.roles.count;
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return CMSignupRoleDisplayName(self.roles[row]);
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.selectedRoleIndex = row;
    self.roleField.text = CMSignupRoleDisplayName(self.roles[row]);
    [CMHaptics selectionChanged];
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
