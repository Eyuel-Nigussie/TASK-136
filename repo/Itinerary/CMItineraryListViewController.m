//
//  CMItineraryListViewController.m
//  CourierMatch
//

#import "CMItineraryListViewController.h"
#import "CMItinerary.h"
#import "CMItineraryDetailViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMItineraryImporter.h"
#import "CMMatchListViewController.h"
#import "CMItineraryRepository.h"
#import "CMMatchEngine.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMDateFormatters.h"
#import "CMAddress.h"
#import "CMHaptics.h"
#import "CMUserAccount.h"
#import "CMPermissionMatrix.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSString * const kCellId = @"ItineraryCell";

#pragma mark - Itinerary Table Cell

@interface CMItineraryCell : UITableViewCell
@property (nonatomic, strong) UILabel *routeLabel;
@property (nonatomic, strong) UILabel *departureLabel;
@property (nonatomic, strong) UILabel *vehicleLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@end

@implementation CMItineraryCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.backgroundColor = [UIColor systemBackgroundColor];

        _routeLabel = [[UILabel alloc] init];
        _routeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _routeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _routeLabel.adjustsFontForContentSizeCategory = YES;
        _routeLabel.numberOfLines = 2;
        _routeLabel.textColor = [UIColor labelColor];

        _departureLabel = [[UILabel alloc] init];
        _departureLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _departureLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        _departureLabel.adjustsFontForContentSizeCategory = YES;
        _departureLabel.textColor = [UIColor secondaryLabelColor];

        _vehicleLabel = [[UILabel alloc] init];
        _vehicleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _vehicleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _vehicleLabel.adjustsFontForContentSizeCategory = YES;
        _vehicleLabel.textColor = [UIColor secondaryLabelColor];

        _statusBadge = [[UILabel alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _statusBadge.adjustsFontForContentSizeCategory = YES;
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 6;
        _statusBadge.layer.masksToBounds = YES;
        _statusBadge.textColor = [UIColor whiteColor];

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_routeLabel, _departureLabel, _vehicleLabel]];
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 4;

        [self.contentView addSubview:textStack];
        [self.contentView addSubview:_statusBadge];

        [NSLayoutConstraint activateConstraints:@[
            [textStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [textStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [textStack.trailingAnchor constraintEqualToAnchor:_statusBadge.leadingAnchor constant:-12],
            [textStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

            [_statusBadge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [_statusBadge.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:70],
            [_statusBadge.heightAnchor constraintGreaterThanOrEqualToConstant:24],
        ]];
    }
    return self;
}

- (void)configureWithItinerary:(CMItinerary *)itin {
    NSString *origin = itin.originAddress.city ?: @"Unknown";
    NSString *dest = itin.destinationAddress.city ?: @"Unknown";
    self.routeLabel.text = [NSString stringWithFormat:@"%@ \u2192 %@", origin, dest];
    self.routeLabel.accessibilityLabel = [NSString stringWithFormat:@"Route from %@ to %@", origin, dest];

    NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
    NSString *startStr = itin.departureWindowStart ? [timeFmt stringFromDate:itin.departureWindowStart] : @"--";
    NSString *endStr = itin.departureWindowEnd ? [timeFmt stringFromDate:itin.departureWindowEnd] : @"--";
    self.departureLabel.text = [NSString stringWithFormat:@"Departs %@ - %@", startStr, endStr];

    self.vehicleLabel.text = [NSString stringWithFormat:@"Vehicle: %@", itin.vehicleType ?: @"N/A"];

    self.statusBadge.text = [NSString stringWithFormat:@" %@ ", itin.status ?: @"--"];
    self.statusBadge.accessibilityLabel = [NSString stringWithFormat:@"Status: %@", itin.status];

    if ([itin.status isEqualToString:CMItineraryStatusActive]) {
        self.statusBadge.backgroundColor = [UIColor systemGreenColor];
    } else if ([itin.status isEqualToString:CMItineraryStatusDraft]) {
        self.statusBadge.backgroundColor = [UIColor systemOrangeColor];
    } else if ([itin.status isEqualToString:CMItineraryStatusCompleted]) {
        self.statusBadge.backgroundColor = [UIColor systemBlueColor];
    } else {
        self.statusBadge.backgroundColor = [UIColor systemGrayColor];
    }
}

@end

#pragma mark - Itinerary List VC

@interface CMItineraryListViewController () <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *lastRefreshedLabel;
@property (nonatomic, strong) NSArray<CMItinerary *> *itineraries;
@property (nonatomic, strong) CMItineraryRepository *repository;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) CMItineraryImporter *importer;
@end

@implementation CMItineraryListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"My Itineraries";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.repository = [[CMItineraryRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    self.itineraries = @[];
    self.importer = [[CMItineraryImporter alloc] init];

    [self setupAddButton];
    [self setupTableView];
    [self setupLastRefreshedLabel];
    [self loadData];
}

- (void)setupAddButton {
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                              target:self
                                                                              action:@selector(addButtonTapped)];
    addButton.accessibilityLabel = @"Create or import itinerary";
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)addButtonTapped {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"New Itinerary"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Create Manually"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        CMItineraryFormViewController *formVC = [[CMItineraryFormViewController alloc] initWithItinerary:nil];
        [self.navigationController pushViewController:formVC animated:YES];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Import CSV/JSON"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self presentDocumentPicker];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    // iPad popover anchor
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)presentDocumentPicker {
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        UTType *csvType = [UTType typeWithIdentifier:@"public.comma-separated-values-text"];
        UTType *jsonType = UTTypeJSON;
        NSMutableArray<UTType *> *types = [NSMutableArray array];
        if (csvType) [types addObject:csvType];
        if (jsonType) [types addObject:jsonType];
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.comma-separated-values-text", @"public.json"]
                                                                       inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *fileURL = urls.firstObject;
    if (!fileURL) return;

    // Start security-scoped access
    BOOL accessing = [fileURL startAccessingSecurityScopedResource];

    [self.importer importFromURL:fileURL completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        if (accessing) {
            [fileURL stopAccessingSecurityScopedResource];
        }

        if (error && !itineraries) {
            [CMHaptics error];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Failed"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        [CMHaptics success];
        NSString *msg = [NSString stringWithFormat:@"Imported %lu itinerar%@.",
                         (unsigned long)itineraries.count,
                         itineraries.count == 1 ? @"y" : @"ies"];
        if (error) {
            // Partial success with warnings
            msg = [NSString stringWithFormat:@"%@ %@", msg, error.localizedDescription];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Import Complete"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

        [self loadData];
    }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    // No action needed
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 88;
    [_tableView registerClass:[CMItineraryCell class] forCellReuseIdentifier:kCellId];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.accessibilityLabel = @"Pull to refresh itineraries and recompute matches";
    [_refreshControl addTarget:self action:@selector(handlePullToRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
    ]];
}

- (void)setupLastRefreshedLabel {
    _lastRefreshedLabel = [[UILabel alloc] init];
    _lastRefreshedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _lastRefreshedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _lastRefreshedLabel.adjustsFontForContentSizeCategory = YES;
    _lastRefreshedLabel.textColor = [UIColor tertiaryLabelColor];
    _lastRefreshedLabel.textAlignment = NSTextAlignmentCenter;
    _lastRefreshedLabel.text = [[CMMatchEngine shared] lastRefreshedDisplayString];

    [self.view addSubview:_lastRefreshedLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_lastRefreshedLabel.topAnchor constraintEqualToAnchor:_tableView.bottomAnchor constant:4],
        [_lastRefreshedLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_lastRefreshedLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [_lastRefreshedLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-4],
        [_lastRefreshedLabel.heightAnchor constraintGreaterThanOrEqualToConstant:20],
    ]];
}

- (void)loadData {
    NSString *courierId = [CMTenantContext shared].currentUserId;
    if (!courierId) { return; }

    NSError *error = nil;
    // Show both active and draft itineraries (not completed/cancelled).
    NSPredicate *p = [NSPredicate predicateWithFormat:
                      @"courierId == %@ AND (status == %@ OR status == %@)",
                      courierId, CMItineraryStatusActive, CMItineraryStatusDraft];
    NSArray *sorts = @[[NSSortDescriptor sortDescriptorWithKey:@"departureWindowStart" ascending:YES]];
    NSArray<CMItinerary *> *results = [self.repository fetchWithPredicate:p
                                                          sortDescriptors:sorts
                                                                    limit:0
                                                                    error:&error];
    if (results) {
        self.itineraries = results;
    } else {
        self.itineraries = @[];
    }
    [self.tableView reloadData];

    if (self.itineraries.count == 0) {
        self.lastRefreshedLabel.text = @"Tap + to create or import an itinerary";
    } else {
        NSString *matchStatus = [[CMMatchEngine shared] lastRefreshedDisplayString];
        if ([matchStatus isEqualToString:@"Not yet refreshed"]) {
            self.lastRefreshedLabel.text = @"Pull down to compute matches";
        } else {
            self.lastRefreshedLabel.text = matchStatus;
        }
    }
}

- (void)handlePullToRefresh {
    [CMHaptics selectionChanged];
    __block NSInteger pending = (NSInteger)self.itineraries.count;
    if (pending == 0) {
        [self.refreshControl endRefreshing];
        return;
    }

    for (CMItinerary *itin in self.itineraries) {
        [[CMMatchEngine shared] recomputeCandidatesForItinerary:itin completion:^(NSError * _Nullable err) {
            pending--;
            if (pending <= 0) {
                [self.refreshControl endRefreshing];
                [self loadData];
                [CMHaptics success];
            }
        }];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.itineraries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CMItineraryCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellId forIndexPath:indexPath];
    CMItinerary *itin = self.itineraries[indexPath.row];
    [cell configureWithItinerary:itin];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CMItinerary *itin = self.itineraries[indexPath.row];
    CMMatchListViewController *matchVC = [[CMMatchListViewController alloc] initWithItinerary:itin];
    [self.navigationController pushViewController:matchVC animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *detailAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                               title:@"Detail"
                                                                             handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        CMItinerary *itin = self.itineraries[indexPath.row];
        CMItineraryDetailViewController *detailVC = [[CMItineraryDetailViewController alloc] initWithItinerary:itin];
        [self.navigationController pushViewController:detailVC animated:YES];
        completionHandler(YES);
    }];
    detailAction.backgroundColor = [UIColor systemBlueColor];
    detailAction.accessibilityLabel = @"View itinerary details";
    return [UISwipeActionsConfiguration configurationWithActions:@[detailAction]];
}

@end
