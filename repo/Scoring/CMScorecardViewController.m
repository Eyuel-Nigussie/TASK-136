//
//  CMScorecardViewController.m
//  CourierMatch
//

#import "CMScorecardViewController.h"
#import "CMDeliveryScorecard.h"
#import "CMScoringEngine.h"
#import "CMRubricTemplate.h"
#import "CMRubricRepository.h"
#import "CMCoreDataStack.h"
#import "CMHaptics.h"
#import "CMSessionManager.h"

static NSString * const kAutoCellId = @"AutoCell";
static NSString * const kManualCellId = @"ManualCell";
static NSString * const kBannerCellId = @"BannerCell";

typedef NS_ENUM(NSInteger, CMScorecardSection) {
    CMScorecardSectionBanner = 0,
    CMScorecardSectionAutomatic,
    CMScorecardSectionManual,
    CMScorecardSectionFinalize,
    CMScorecardSectionCount
};

#pragma mark - Manual Grade Cell

@interface CMManualGradeCell : UITableViewCell
@property (nonatomic, strong) UILabel *itemLabel;
@property (nonatomic, strong) UILabel *pointsLabel;
@property (nonatomic, strong) UIStepper *stepper;
@property (nonatomic, strong) UITextField *notesField;
@property (nonatomic, assign) double maxPoints;
@property (nonatomic, copy) NSString *itemKey;
@property (nonatomic, copy) void (^onGradeChanged)(NSString *itemKey, double points, NSString *notes);
@end

@implementation CMManualGradeCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

        _itemLabel = [[UILabel alloc] init];
        _itemLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _itemLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _itemLabel.adjustsFontForContentSizeCategory = YES;
        _itemLabel.textColor = [UIColor labelColor];
        _itemLabel.numberOfLines = 0;

        _pointsLabel = [[UILabel alloc] init];
        _pointsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _pointsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _pointsLabel.adjustsFontForContentSizeCategory = YES;
        _pointsLabel.textColor = [UIColor systemBlueColor];
        _pointsLabel.textAlignment = NSTextAlignmentCenter;

        _stepper = [[UIStepper alloc] init];
        _stepper.translatesAutoresizingMaskIntoConstraints = NO;
        _stepper.minimumValue = 0;
        _stepper.stepValue = 1;
        _stepper.accessibilityLabel = @"Adjust score points";
        [_stepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];

        _notesField = [[UITextField alloc] init];
        _notesField.translatesAutoresizingMaskIntoConstraints = NO;
        _notesField.borderStyle = UITextBorderStyleRoundedRect;
        _notesField.placeholder = @"Notes (required when below half)";
        _notesField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _notesField.adjustsFontForContentSizeCategory = YES;
        _notesField.accessibilityLabel = @"Grading notes";
        _notesField.returnKeyType = UIReturnKeyDone;

        UIStackView *scoreRow = [[UIStackView alloc] initWithArrangedSubviews:@[_pointsLabel, _stepper]];
        scoreRow.translatesAutoresizingMaskIntoConstraints = NO;
        scoreRow.axis = UILayoutConstraintAxisHorizontal;
        scoreRow.spacing = 8;
        scoreRow.alignment = UIStackViewAlignmentCenter;

        UIStackView *mainStack = [[UIStackView alloc] initWithArrangedSubviews:@[_itemLabel, scoreRow, _notesField]];
        mainStack.translatesAutoresizingMaskIntoConstraints = NO;
        mainStack.axis = UILayoutConstraintAxisVertical;
        mainStack.spacing = 8;

        [self.contentView addSubview:mainStack];
        [NSLayoutConstraint activateConstraints:@[
            [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            [_notesField.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        ]];
    }
    return self;
}

- (void)configureWithItemName:(NSString *)name key:(NSString *)key
                   maxPoints:(double)maxPts currentPoints:(double)currentPts
                       notes:(NSString *)notes finalized:(BOOL)finalized {
    self.itemKey = key;
    self.maxPoints = maxPts;
    self.itemLabel.text = [NSString stringWithFormat:@"%@ (max %.0f pts)", name, maxPts];
    self.pointsLabel.text = [NSString stringWithFormat:@"%.0f", currentPts];
    self.stepper.maximumValue = maxPts;
    self.stepper.value = currentPts;
    self.notesField.text = notes;

    self.stepper.enabled = !finalized;
    self.notesField.enabled = !finalized;

    // Highlight notes required when below half
    if (currentPts < maxPts / 2.0 && (!notes || notes.length == 0)) {
        self.notesField.layer.borderColor = [UIColor systemRedColor].CGColor;
        self.notesField.layer.borderWidth = 1.0;
        self.notesField.placeholder = @"Notes REQUIRED (score below half)";
    } else {
        self.notesField.layer.borderColor = [UIColor clearColor].CGColor;
        self.notesField.layer.borderWidth = 0;
        self.notesField.placeholder = @"Notes (required when below half)";
    }
}

- (void)stepperChanged:(UIStepper *)stepper {
    self.pointsLabel.text = [NSString stringWithFormat:@"%.0f", stepper.value];
    if (self.onGradeChanged) {
        self.onGradeChanged(self.itemKey, stepper.value, self.notesField.text);
    }
}

@end

#pragma mark - Scorecard VC

@interface CMScorecardViewController ()
@property (nonatomic, strong) CMDeliveryScorecard *scorecard;
@property (nonatomic, strong) CMScoringEngine *engine;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) CMRubricTemplate *rubric;
@property (nonatomic, assign) BOOL upgradeAvailable;
@property (nonatomic, copy) NSString *latestRubricId;
@property (nonatomic, strong) NSArray *autoItems;
@property (nonatomic, strong) NSArray *manualItems;
@end

@implementation CMScorecardViewController

- (instancetype)initWithScorecard:(CMDeliveryScorecard *)scorecard {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _scorecard = scorecard;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Scorecard";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.engine = [[CMScoringEngine alloc] initWithContext:[CMCoreDataStack shared].viewContext];

    [self loadRubric];
    [self checkUpgrade];
    [self setupTableView];
}

- (void)loadRubric {
    CMRubricRepository *rubricRepo = [[CMRubricRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    NSError *error = nil;
    self.rubric = [rubricRepo findById:self.scorecard.rubricId
                         rubricVersion:self.scorecard.rubricVersion
                                 error:&error];

    // Separate items into auto and manual
    NSMutableArray *autoArr = [NSMutableArray array];
    NSMutableArray *manualArr = [NSMutableArray array];
    for (NSDictionary *item in self.rubric.items) {
        NSString *mode = item[@"mode"];
        if ([mode isEqualToString:@"automatic"]) {
            [autoArr addObject:item];
        } else {
            [manualArr addObject:item];
        }
    }
    self.autoItems = [autoArr copy];
    self.manualItems = [manualArr copy];
}

- (void)checkUpgrade {
    NSDictionary *info = [self.engine checkRubricUpgradeAvailable:self.scorecard];
    self.upgradeAvailable = [info[CMRubricUpgradeAvailableKey] boolValue];
    if (self.upgradeAvailable) {
        self.latestRubricId = info[CMRubricUpgradeLatestRubricIdKey];
    }
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 80;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kAutoCellId];
    [_tableView registerClass:[CMManualGradeCell class] forCellReuseIdentifier:kManualCellId];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kBannerCellId];

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (NSDictionary *)autoResultForKey:(NSString *)key {
    for (NSDictionary *r in self.scorecard.automatedResults) {
        if ([r[@"itemKey"] isEqualToString:key]) return r;
    }
    return nil;
}

- (NSDictionary *)manualResultForKey:(NSString *)key {
    for (NSDictionary *r in self.scorecard.manualResults) {
        if ([r[@"itemKey"] isEqualToString:key]) return r;
    }
    return nil;
}

#pragma mark - Actions

- (void)finalizeTapped {
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

    NSError *error = nil;
    BOOL success = [self.engine finalizeScorecard:self.scorecard error:&error];
    if (success) {
        [CMHaptics success];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Finalized"
                                                                      message:@"Scorecard has been finalized successfully."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self.tableView reloadData];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [CMHaptics error];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                      message:error.localizedDescription ?: @"Failed to finalize scorecard."
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)upgradeTapped {
    NSError *error = nil;
    CMDeliveryScorecard *newScorecard = [self.engine upgradeScorecardRubric:self.scorecard error:&error];
    if (newScorecard) {
        self.scorecard = newScorecard;
        [self loadRubric];
        [self checkUpgrade];
        [self.tableView reloadData];
        [CMHaptics success];
    } else {
        [CMHaptics error];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Upgrade Error"
                                                                      message:error.localizedDescription
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CMScorecardSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((CMScorecardSection)section) {
        case CMScorecardSectionBanner: return self.upgradeAvailable ? @"Rubric Update" : nil;
        case CMScorecardSectionAutomatic: return @"Automatic Scores";
        case CMScorecardSectionManual: return @"Manual Scores";
        case CMScorecardSectionFinalize: return nil;
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((CMScorecardSection)section) {
        case CMScorecardSectionBanner: return self.upgradeAvailable ? 1 : 0;
        case CMScorecardSectionAutomatic: return (NSInteger)self.autoItems.count;
        case CMScorecardSectionManual: return (NSInteger)self.manualItems.count;
        case CMScorecardSectionFinalize: return [self.scorecard isFinalized] ? 0 : 1;
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch ((CMScorecardSection)indexPath.section) {
        case CMScorecardSectionBanner: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kBannerCellId forIndexPath:indexPath];
            cell.backgroundColor = [UIColor systemYellowColor];
            cell.textLabel.text = @"A newer rubric version is available. Tap to upgrade.";
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textColor = [UIColor blackColor];
            cell.accessibilityLabel = @"Newer rubric version available. Tap to upgrade.";
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        }
        case CMScorecardSectionAutomatic: {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kAutoCellId forIndexPath:indexPath];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            cell.textLabel.numberOfLines = 0;

            NSDictionary *item = self.autoItems[indexPath.row];
            NSString *key = item[@"itemKey"] ?: @"";
            NSString *name = item[@"label"] ?: key;
            double maxPts = [item[@"maxPoints"] doubleValue];

            NSDictionary *result = [self autoResultForKey:key];
            double pts = [result[@"points"] doubleValue];
            NSString *evidence = result[@"evidence"] ?: @"";

            cell.textLabel.text = [NSString stringWithFormat:@"%@\n%.0f / %.0f pts\n%@", name, pts, maxPts, evidence];
            cell.accessibilityLabel = [NSString stringWithFormat:@"%@: %.0f of %.0f points. %@", name, pts, maxPts, evidence];
            return cell;
        }
        case CMScorecardSectionManual: {
            CMManualGradeCell *cell = [tableView dequeueReusableCellWithIdentifier:kManualCellId forIndexPath:indexPath];
            NSDictionary *item = self.manualItems[indexPath.row];
            NSString *key = item[@"itemKey"] ?: @"";
            NSString *name = item[@"label"] ?: key;
            double maxPts = [item[@"maxPoints"] doubleValue];

            NSDictionary *result = [self manualResultForKey:key];
            double currentPts = [result[@"points"] doubleValue];
            NSString *notes = result[@"notes"] ?: @"";

            [cell configureWithItemName:name key:key maxPoints:maxPts currentPoints:currentPts
                                  notes:notes finalized:[self.scorecard isFinalized]];

            __weak typeof(self) weakSelf = self;
            cell.onGradeChanged = ^(NSString *itemKey, double points, NSString *notesStr) {
                NSError *err = nil;
                [weakSelf.engine recordManualGrade:weakSelf.scorecard
                                           itemKey:itemKey
                                            points:points
                                             notes:notesStr
                                             error:&err];
                if (err) {
                    [CMHaptics warning];
                }
            };
            return cell;
        }
        case CMScorecardSectionFinalize: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor systemBlueColor];
            cell.textLabel.text = @"Finalize Scorecard";
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.accessibilityLabel = @"Finalize scorecard";
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            return cell;
        }
        default: {
            return [tableView dequeueReusableCellWithIdentifier:kAutoCellId forIndexPath:indexPath];
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == CMScorecardSectionBanner) {
        [self upgradeTapped];
    } else if (indexPath.section == CMScorecardSectionFinalize) {
        [self finalizeTapped];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == CMScorecardSectionFinalize) {
        return 50;
    }
    return UITableViewAutomaticDimension;
}

@end
