//
//  CMAdminDashboardViewController.m
//  CourierMatch
//

#import "CMAdminDashboardViewController.h"
#import "CMUserRepository.h"
#import "CMUserAccount.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMPermissionChangeAuditor.h"
#import "CMAuditVerifier.h"
#import "CMDebugLogger.h"
#import "CMSessionManager.h"
#import "CMHaptics.h"
#import "CMDateFormatters.h"

typedef NS_ENUM(NSInteger, CMAdminSection) {
    CMAdminSectionUserManagement = 0,
    CMAdminSectionDiagnostics,
    CMAdminSectionForcedLogout,
    CMAdminSectionCount
};

#pragma mark - User Cell

@interface CMAdminUserCell : UITableViewCell
@property (nonatomic, strong) UILabel *usernameLabel;
@property (nonatomic, strong) UILabel *roleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation CMAdminUserCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        _usernameLabel = [[UILabel alloc] init];
        _usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _usernameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _usernameLabel.adjustsFontForContentSizeCategory = YES;
        _usernameLabel.textColor = [UIColor labelColor];

        _roleLabel = [[UILabel alloc] init];
        _roleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _roleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _roleLabel.adjustsFontForContentSizeCategory = YES;
        _roleLabel.textColor = [UIColor secondaryLabelColor];

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _statusLabel.adjustsFontForContentSizeCategory = YES;
        _statusLabel.textColor = [UIColor tertiaryLabelColor];

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_usernameLabel, _roleLabel, _statusLabel]];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 2;

        [self.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        ]];
    }
    return self;
}

- (void)configureWithUser:(CMUserAccount *)user {
    self.usernameLabel.text = user.displayName ?: user.username;
    self.roleLabel.text = [NSString stringWithFormat:@"Role: %@", user.role];
    self.statusLabel.text = [NSString stringWithFormat:@"Status: %@", user.status];
    self.accessibilityLabel = [NSString stringWithFormat:@"User %@, role %@, status %@",
                               user.displayName ?: user.username, user.role, user.status];
}

@end

#pragma mark - Admin Dashboard VC

static NSString * const kUserCellId = @"UserCell";
static NSString * const kActionCellId = @"ActionCell";

@interface CMAdminDashboardViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<CMUserAccount *> *users;
@property (nonatomic, strong) CMUserRepository *userRepository;
@property (nonatomic, strong) UILabel *accessDeniedLabel;
@end

@implementation CMAdminDashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Admin Dashboard";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Role gate: only admin can see this
    NSString *role = [CMTenantContext shared].currentRole;
    if (![role isEqualToString:@"admin"]) {
        [self showAccessDenied];
        return;
    }

    self.userRepository = [[CMUserRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    self.users = @[];

    [self setupSearchBar];
    [self setupTableView];
    [self loadUsers:@""];
}

- (void)showAccessDenied {
    _accessDeniedLabel = [[UILabel alloc] init];
    _accessDeniedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _accessDeniedLabel.text = @"Access Denied\nAdmin role required";
    _accessDeniedLabel.numberOfLines = 0;
    _accessDeniedLabel.textAlignment = NSTextAlignmentCenter;
    _accessDeniedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    _accessDeniedLabel.adjustsFontForContentSizeCategory = YES;
    _accessDeniedLabel.textColor = [UIColor secondaryLabelColor];
    _accessDeniedLabel.accessibilityLabel = @"Access denied. Admin role required.";

    [self.view addSubview:_accessDeniedLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_accessDeniedLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_accessDeniedLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_accessDeniedLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_accessDeniedLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
    ]];
}

- (void)setupSearchBar {
    _searchBar = [[UISearchBar alloc] init];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    _searchBar.placeholder = @"Search users by username";
    _searchBar.delegate = self;
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.accessibilityLabel = @"Search users";

    [self.view addSubview:_searchBar];
    [NSLayoutConstraint activateConstraints:@[
        [_searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_searchBar.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_searchBar.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 60;
    [_tableView registerClass:[CMAdminUserCell class] forCellReuseIdentifier:kUserCellId];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kActionCellId];

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_searchBar.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (void)loadUsers:(NSString *)prefix {
    NSError *error = nil;
    NSArray<CMUserAccount *> *results = [self.userRepository searchByUsernamePrefix:prefix limit:100 error:&error];
    self.users = results ?: @[];
    [self.tableView reloadData];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self loadUsers:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Actions

- (void)changeRole:(CMUserAccount *)user {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Change Role"
                                                                  message:[NSString stringWithFormat:@"Current role: %@", user.role]
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *roles = @[CMUserRoleCourier, CMUserRoleDispatcher, CMUserRoleReviewer,
                       CMUserRoleCustomerService, CMUserRoleFinance, CMUserRoleAdmin];
    for (NSString *role in roles) {
        if ([role isEqualToString:user.role]) continue;
        [sheet addAction:[UIAlertAction actionWithTitle:role style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self performRoleChange:user toRole:role];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)performRoleChange:(CMUserAccount *)user toRole:(NSString *)newRole {
    // Preflight session check
    NSError *preflightErr = nil;
    if (![[CMSessionManager shared] preflightSensitiveActionWithError:&preflightErr]) {
        [CMHaptics error];
        return;
    }

    NSString *oldRole = user.role;
    user.role = newRole;
    user.updatedAt = [NSDate date];

    NSError *saveErr = nil;
    [user.managedObjectContext save:&saveErr];

    if (saveErr) {
        [CMHaptics error];
        user.role = oldRole; // revert
        return;
    }

    // Record through CMPermissionChangeAuditor
    [[CMPermissionChangeAuditor shared] recordRoleChange:user.userId
                                                 oldRole:oldRole
                                                 newRole:newRole
                                                  reason:@"Admin dashboard role change"
                                              completion:^(CMAuditEntry *entry, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!err) {
                [CMHaptics success];
            } else {
                [CMHaptics warning];
            }
        });
    }];

    [self.tableView reloadData];
}

- (void)forceLogout:(CMUserAccount *)user {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Force Logout"
                                                                    message:[NSString stringWithFormat:@"Force logout user %@?", user.displayName ?: user.username]
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Force Logout" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        user.forceLogoutAt = [NSDate date];
        user.updatedAt = [NSDate date];

        NSError *err = nil;
        [user.managedObjectContext save:&err];
        if (!err) {
            [CMHaptics success];
        } else {
            [CMHaptics error];
        }
        [self.tableView reloadData];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)showDiagnostics {
    NSArray<NSString *> *logs = [[CMDebugLogger shared] currentBufferSnapshot];
    NSString *logText = logs.count > 0 ? [logs componentsJoinedByString:@"\n"] : @"No debug logs available.";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Debug Log"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];

    // Use a text view in the alert for scrollable content
    UITextView *textView = [[UITextView alloc] init];
    textView.text = logText;
    textView.editable = NO;
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    textView.adjustsFontForContentSizeCategory = YES;
    textView.textColor = [UIColor labelColor];
    textView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    textView.accessibilityLabel = @"Debug log contents";

    [alert addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self shareLogText:logText];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Verify Audit Chain" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self verifyAuditChain];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:alert animated:YES completion:^{
        // Add text view to alert after presentation
        UIView *contentView = alert.view;
        [contentView addSubview:textView];
        textView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [textView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:60],
            [textView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:10],
            [textView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10],
            [textView.heightAnchor constraintEqualToConstant:200],
        ]];

        // Adjust alert height
        NSLayoutConstraint *height = [contentView.heightAnchor constraintGreaterThanOrEqualToConstant:360];
        height.priority = UILayoutPriorityDefaultHigh;
        height.active = YES;
    }];
}

- (void)shareLogText:(NSString *)logText {
    // Warn the admin that debug logs may contain operational identifiers
    // before proceeding with the export.
    UIAlertController *warning = [UIAlertController alertControllerWithTitle:@"Export Warning"
                                                                    message:@"Debug logs may contain operational identifiers. Ensure export is handled securely."
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [warning addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [warning addAction:[UIAlertAction actionWithTitle:@"Export" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // Create temp file for share sheet export per section 16
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"couriermatch-debug.log"];
        [logText writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];

        UIActivityViewController *shareVC = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
        shareVC.popoverPresentationController.sourceView = self.view;
        shareVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, 100, 0, 0);
        [self presentViewController:shareVC animated:YES completion:nil];
    }]];
    [self presentViewController:warning animated:YES completion:nil];
}

- (void)verifyAuditChain {
    NSString *tenantId = [CMTenantContext shared].currentTenantId;
    if (!tenantId) return;

    UIAlertController *progress = [UIAlertController alertControllerWithTitle:@"Verifying..."
                                                                     message:@"Checking audit chain integrity."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progress animated:YES completion:nil];

    [[CMAuditVerifier shared] verifyChainForTenant:tenantId progress:nil completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [progress dismissViewControllerAnimated:YES completion:^{
                NSString *title = success ? @"Chain Verified" : @"Chain Broken";
                NSString *msg = success ? @"Audit chain integrity is intact." :
                    [NSString stringWithFormat:@"Chain broken at entry: %@", brokenEntryId ?: @"unknown"];

                UIAlertController *result = [UIAlertController alertControllerWithTitle:title
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:result animated:YES completion:nil];

                if (success) {
                    [CMHaptics success];
                } else {
                    [CMHaptics error];
                }
            }];
        });
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CMAdminSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((CMAdminSection)section) {
        case CMAdminSectionUserManagement: return @"User Management";
        case CMAdminSectionDiagnostics: return @"Diagnostics";
        case CMAdminSectionForcedLogout: return @"Force Logout";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((CMAdminSection)section) {
        case CMAdminSectionUserManagement:
            return (NSInteger)self.users.count;
        case CMAdminSectionDiagnostics:
            return 2; // View logs, Verify chain
        case CMAdminSectionForcedLogout:
            return (NSInteger)self.users.count;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch ((CMAdminSection)indexPath.section) {
        case CMAdminSectionUserManagement: {
            CMAdminUserCell *cell = [tableView dequeueReusableCellWithIdentifier:kUserCellId forIndexPath:indexPath];
            CMUserAccount *user = self.users[indexPath.row];
            [cell configureWithUser:user];
            return cell;
        }
        case CMAdminSectionDiagnostics: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kActionCellId forIndexPath:indexPath];
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor systemBlueColor];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

            if (indexPath.row == 0) {
                cell.textLabel.text = @"View Debug Logs & Export";
                cell.accessibilityLabel = @"View debug logs and export";
            } else {
                cell.textLabel.text = @"Verify Audit Chain";
                cell.accessibilityLabel = @"Verify audit chain integrity";
            }
            return cell;
        }
        case CMAdminSectionForcedLogout: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
            cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];

            CMUserAccount *user = self.users[indexPath.row];
            cell.textLabel.text = user.displayName ?: user.username;

            if (user.forceLogoutAt) {
                NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
                NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Forced logout at %@ %@",
                                             [dateFmt stringFromDate:user.forceLogoutAt],
                                             [timeFmt stringFromDate:user.forceLogoutAt]];
                cell.detailTextLabel.textColor = [UIColor systemRedColor];
            } else {
                cell.detailTextLabel.text = @"Active session";
            }

            cell.accessibilityLabel = [NSString stringWithFormat:@"Force logout %@", user.displayName ?: user.username];
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        default: {
            return [tableView dequeueReusableCellWithIdentifier:kActionCellId forIndexPath:indexPath];
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch ((CMAdminSection)indexPath.section) {
        case CMAdminSectionUserManagement: {
            CMUserAccount *user = self.users[indexPath.row];
            [self changeRole:user];
            break;
        }
        case CMAdminSectionDiagnostics: {
            if (indexPath.row == 0) {
                [self showDiagnostics];
            } else {
                [self verifyAuditChain];
            }
            break;
        }
        case CMAdminSectionForcedLogout: {
            CMUserAccount *user = self.users[indexPath.row];
            [self forceLogout:user];
            break;
        }
        default:
            break;
    }
}

@end
