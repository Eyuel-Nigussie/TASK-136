//
//  CMAppealReviewViewController.m
//  CourierMatch
//

#import "CMAppealReviewViewController.h"
#import "CMAppeal.h"
#import "CMAppealService.h"
#import "CMAuditRepository.h"
#import "CMAuditEntry.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMSessionManager.h"
#import "CMHaptics.h"
#import "CMDateFormatters.h"

static NSString * const kScoreCellId = @"ScoreCell";
static NSString * const kAuditCellId = @"AuditCell";

typedef NS_ENUM(NSInteger, CMAppealReviewSection) {
    CMAppealReviewSectionInfo = 0,
    CMAppealReviewSectionBeforeScores,
    CMAppealReviewSectionAfterScores,
    CMAppealReviewSectionDecision,
    CMAppealReviewSectionAuditTrail,
    CMAppealReviewSectionCount
};

@interface CMAppealReviewViewController () <UITableViewDataSource, UITableViewDelegate,
                                             UIPickerViewDataSource, UIPickerViewDelegate>
@property (nonatomic, strong) CMAppeal *appeal;
@property (nonatomic, strong) CMAppealService *appealService;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *decisionOptions;
@property (nonatomic, assign) NSInteger selectedDecision;
@property (nonatomic, strong) NSMutableDictionary *afterScores;
@property (nonatomic, strong) NSString *decisionNotes;
@property (nonatomic, strong) NSArray<CMAuditEntry *> *auditEntries;
@property (nonatomic, strong) NSArray<NSString *> *scoreKeys;
@end

@implementation CMAppealReviewViewController

- (instancetype)initWithAppeal:(CMAppeal *)appeal {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _appeal = appeal;
        _decisionOptions = @[CMAppealDecisionUphold, CMAppealDecisionAdjust, CMAppealDecisionReject];
        _selectedDecision = 0;
        _afterScores = [NSMutableDictionary dictionary];
        _decisionNotes = @"";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Appeal Review";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.appealService = [[CMAppealService alloc] initWithContext:[CMCoreDataStack shared].viewContext];

    [self extractScoreKeys];
    [self initAfterScores];
    [self loadAuditTrail];
    [self setupTableView];
}

- (void)extractScoreKeys {
    NSDictionary *before = self.appeal.beforeScoreSnapshotJSON;
    if (before) {
        self.scoreKeys = [before.allKeys sortedArrayUsingSelector:@selector(compare:)];
    } else {
        self.scoreKeys = @[];
    }
}

- (void)initAfterScores {
    NSDictionary *after = self.appeal.afterScoreSnapshotJSON;
    if (after) {
        [self.afterScores addEntriesFromDictionary:after];
    } else {
        // Initialize from before scores for editing
        NSDictionary *before = self.appeal.beforeScoreSnapshotJSON;
        if (before) {
            [self.afterScores addEntriesFromDictionary:before];
        }
    }
}

- (void)loadAuditTrail {
    CMAuditRepository *auditRepo = [[CMAuditRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    NSError *error = nil;
    // Fetch audit entries for this appeal
    NSArray *entries = [auditRepo fetchWithPredicate:[NSPredicate predicateWithFormat:@"targetId == %@ AND targetType == %@",
                                                     self.appeal.appealId, @"Appeal"]
                                     sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]
                                               limit:100
                                               error:&error];
    self.auditEntries = entries ?: @[];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 50;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

#pragma mark - Actions

- (void)submitDecision {
    // Preflight session check
    NSError *preflightErr = nil;
    if (![[CMSessionManager shared] preflightSensitiveActionWithError:&preflightErr]) {
        [CMHaptics error];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Session Error"
                                                                      message:preflightErr.localizedDescription
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *decision = self.decisionOptions[self.selectedDecision];
    if (self.decisionNotes.length == 0) {
        [CMHaptics warning];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Validation Error"
                                                                      message:@"Decision notes are required."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Finance gate for monetary impact
    if (self.appeal.monetaryImpact) {
        NSString *role = [CMTenantContext shared].currentRole;
        if (![role isEqualToString:@"finance"]) {
            [CMHaptics error];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Access Denied"
                                                                          message:@"Finance role required for appeals with monetary impact."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
    }

    NSDictionary *afterDict = [decision isEqualToString:CMAppealDecisionAdjust] ? [self.afterScores copy] : nil;

    NSError *error = nil;
    BOOL success = [self.appealService submitDecision:decision
                                              appeal:self.appeal
                                         afterScores:afterDict
                                               notes:self.decisionNotes
                                               error:&error];
    if (success) {
        [CMHaptics success];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Decision Submitted"
                                                                      message:@"The appeal decision has been recorded."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.navigationController popViewControllerAnimated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [CMHaptics error];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                      message:error.localizedDescription ?: @"Failed to submit decision."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CMAppealReviewSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((CMAppealReviewSection)section) {
        case CMAppealReviewSectionInfo: return @"Appeal Info";
        case CMAppealReviewSectionBeforeScores: return @"Before Scores";
        case CMAppealReviewSectionAfterScores: {
            NSString *decision = self.decisionOptions[self.selectedDecision];
            return [decision isEqualToString:CMAppealDecisionAdjust] ? @"Proposed After Scores" : nil;
        }
        case CMAppealReviewSectionDecision: return @"Decision";
        case CMAppealReviewSectionAuditTrail: return @"Audit Trail";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((CMAppealReviewSection)section) {
        case CMAppealReviewSectionInfo: {
            NSInteger rows = 3; // reason, opened by, opened at
            if (self.appeal.monetaryImpact) rows++; // finance gate
            return rows;
        }
        case CMAppealReviewSectionBeforeScores:
            return (NSInteger)self.scoreKeys.count;
        case CMAppealReviewSectionAfterScores: {
            NSString *decision = self.decisionOptions[self.selectedDecision];
            return [decision isEqualToString:CMAppealDecisionAdjust] ? (NSInteger)self.scoreKeys.count : 0;
        }
        case CMAppealReviewSectionDecision:
            return 3; // picker, notes, submit button
        case CMAppealReviewSectionAuditTrail:
            return MAX((NSInteger)self.auditEntries.count, 1);
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.numberOfLines = 0;

    switch ((CMAppealReviewSection)indexPath.section) {
        case CMAppealReviewSectionInfo: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Reason";
                cell.detailTextLabel.text = self.appeal.reason;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Opened By";
                cell.detailTextLabel.text = self.appeal.openedBy;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Opened At";
                NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
                NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@",
                                             [dateFmt stringFromDate:self.appeal.openedAt],
                                             [timeFmt stringFromDate:self.appeal.openedAt]];
            } else {
                // Monetary impact warning
                cell.textLabel.text = @"Monetary Impact";
                cell.detailTextLabel.text = @"Finance role required";
                cell.detailTextLabel.textColor = [UIColor systemRedColor];
                cell.backgroundColor = [UIColor colorWithRed:1.0 green:0.95 blue:0.95 alpha:1.0];
                cell.accessibilityLabel = @"This appeal has monetary impact. Finance role required.";
            }
            break;
        }
        case CMAppealReviewSectionBeforeScores: {
            NSString *key = self.scoreKeys[indexPath.row];
            id value = self.appeal.beforeScoreSnapshotJSON[key];
            cell.textLabel.text = key;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", value];
            cell.accessibilityLabel = [NSString stringWithFormat:@"Before score %@: %@", key, value];
            break;
        }
        case CMAppealReviewSectionAfterScores: {
            NSString *key = self.scoreKeys[indexPath.row];
            id value = self.afterScores[key];
            cell.textLabel.text = key;
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", value];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.accessibilityLabel = [NSString stringWithFormat:@"After score %@: %@. Tap to edit.", key, value];
            break;
        }
        case CMAppealReviewSectionDecision: {
            if (indexPath.row == 0) {
                // Decision picker display
                cell.textLabel.text = @"Decision";
                cell.detailTextLabel.text = self.decisionOptions[self.selectedDecision];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.accessibilityLabel = [NSString stringWithFormat:@"Decision: %@. Tap to change.", self.decisionOptions[self.selectedDecision]];
            } else if (indexPath.row == 1) {
                // Notes
                cell.textLabel.text = @"Notes";
                cell.detailTextLabel.text = self.decisionNotes.length > 0 ? self.decisionNotes : @"Tap to enter";
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessibilityLabel = @"Decision notes. Tap to enter.";
            } else {
                // Submit button
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.backgroundColor = [UIColor systemBlueColor];
                cell.textLabel.text = @"Submit Decision";
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
                cell.textLabel.adjustsFontForContentSizeCategory = YES;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessibilityLabel = @"Submit appeal decision";
                cell.accessibilityTraits = UIAccessibilityTraitButton;
            }
            break;
        }
        case CMAppealReviewSectionAuditTrail: {
            if (self.auditEntries.count == 0) {
                cell.textLabel.text = @"No audit entries";
                cell.textLabel.textColor = [UIColor tertiaryLabelColor];
            } else {
                CMAuditEntry *entry = self.auditEntries[indexPath.row];
                NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
                NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
                cell.textLabel.text = [NSString stringWithFormat:@"%@ - %@",
                                       entry.action,
                                       [NSString stringWithFormat:@"%@ %@",
                                        [dateFmt stringFromDate:entry.createdAt],
                                        [timeFmt stringFromDate:entry.createdAt]]];
                cell.detailTextLabel.text = entry.actorUserId;
                cell.accessibilityLabel = [NSString stringWithFormat:@"Audit: %@ by %@ on %@",
                                           entry.action, entry.actorUserId,
                                           [dateFmt stringFromDate:entry.createdAt]];
            }
            break;
        }
        default:
            break;
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == CMAppealReviewSectionAfterScores) {
        NSString *key = self.scoreKeys[indexPath.row];
        [self showScoreEditorForKey:key];
    } else if (indexPath.section == CMAppealReviewSectionDecision) {
        if (indexPath.row == 0) {
            [self showDecisionPicker];
        } else if (indexPath.row == 1) {
            [self showNotesEditor];
        } else if (indexPath.row == 2) {
            [self submitDecision];
        }
    }
}

#pragma mark - Editors

- (void)showDecisionPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Select Decision"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSInteger i = 0; i < (NSInteger)self.decisionOptions.count; i++) {
        NSString *option = self.decisionOptions[i];
        [sheet addAction:[UIAlertAction actionWithTitle:option style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedDecision = i;
            [CMHaptics selectionChanged];
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showNotesEditor {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Decision Notes"
                                                                  message:@"Enter notes for this decision."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = self.decisionNotes;
        tf.placeholder = @"Decision notes (required)";
        tf.accessibilityLabel = @"Decision notes";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.decisionNotes = alert.textFields.firstObject.text ?: @"";
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showScoreEditorForKey:(NSString *)key {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Edit Score"
                                                                  message:[NSString stringWithFormat:@"Edit score for: %@", key]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [NSString stringWithFormat:@"%@", self.afterScores[key]];
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.accessibilityLabel = [NSString stringWithFormat:@"Score for %@", key];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        double val = text.doubleValue;
        self.afterScores[key] = @(val);
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIPickerViewDataSource/Delegate (unused but conformance declared)

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 1; }
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return (NSInteger)self.decisionOptions.count;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.decisionOptions[row];
}
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.selectedDecision = row;
    [self.tableView reloadData];
}

@end
