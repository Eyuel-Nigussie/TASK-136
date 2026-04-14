//
//  CMMatchListViewController.m
//  CourierMatch
//

#import "CMMatchListViewController.h"
#import "CMItinerary.h"
#import "CMMatchCandidate.h"
#import "CMMatchEngine.h"
#import "CMMatchExplanation.h"
#import "CMOrderRepository.h"
#import "CMOrder.h"
#import "CMCoreDataStack.h"
#import "CMHaptics.h"

static NSString * const kMatchCellId = @"MatchCell";
static NSString * const kSkeletonCellId = @"SkeletonCell";

#pragma mark - Match Cell

@interface CMMatchCell : UITableViewCell
@property (nonatomic, strong) UILabel *rankLabel;
@property (nonatomic, strong) UILabel *orderRefLabel;
@property (nonatomic, strong) UILabel *scoreLabel;
@property (nonatomic, strong) UILabel *explanationLabel;
@property (nonatomic, strong) UILabel *metricsLabel;
@end

@implementation CMMatchCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

        _rankLabel = [[UILabel alloc] init];
        _rankLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _rankLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
        _rankLabel.adjustsFontForContentSizeCategory = YES;
        _rankLabel.textColor = [UIColor systemBlueColor];
        _rankLabel.textAlignment = NSTextAlignmentCenter;

        _orderRefLabel = [[UILabel alloc] init];
        _orderRefLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _orderRefLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _orderRefLabel.adjustsFontForContentSizeCategory = YES;
        _orderRefLabel.textColor = [UIColor labelColor];

        _scoreLabel = [[UILabel alloc] init];
        _scoreLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _scoreLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        _scoreLabel.adjustsFontForContentSizeCategory = YES;
        _scoreLabel.textColor = [UIColor systemOrangeColor];

        _explanationLabel = [[UILabel alloc] init];
        _explanationLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _explanationLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _explanationLabel.adjustsFontForContentSizeCategory = YES;
        _explanationLabel.textColor = [UIColor secondaryLabelColor];
        _explanationLabel.numberOfLines = 0;

        _metricsLabel = [[UILabel alloc] init];
        _metricsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _metricsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _metricsLabel.adjustsFontForContentSizeCategory = YES;
        _metricsLabel.textColor = [UIColor tertiaryLabelColor];

        UIStackView *detailStack = [[UIStackView alloc] initWithArrangedSubviews:@[
            _orderRefLabel, _scoreLabel, _explanationLabel, _metricsLabel
        ]];
        detailStack.translatesAutoresizingMaskIntoConstraints = NO;
        detailStack.axis = UILayoutConstraintAxisVertical;
        detailStack.spacing = 2;

        [self.contentView addSubview:_rankLabel];
        [self.contentView addSubview:detailStack];

        [NSLayoutConstraint activateConstraints:@[
            [_rankLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_rankLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_rankLabel.widthAnchor constraintEqualToConstant:44],
            [_rankLabel.heightAnchor constraintGreaterThanOrEqualToConstant:44],

            [detailStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [detailStack.leadingAnchor constraintEqualToAnchor:_rankLabel.trailingAnchor constant:12],
            [detailStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [detailStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        ]];
    }
    return self;
}

- (void)configureWithCandidate:(CMMatchCandidate *)candidate orderRef:(NSString *)orderRef {
    self.rankLabel.text = [NSString stringWithFormat:@"#%d", candidate.rankPosition];
    self.rankLabel.accessibilityLabel = [NSString stringWithFormat:@"Rank %d", candidate.rankPosition];

    self.orderRefLabel.text = orderRef ?: candidate.orderId;
    self.scoreLabel.text = [NSString stringWithFormat:@"Score: %.1f", candidate.score];

    NSArray *components = candidate.explanationComponents;
    if (components) {
        self.explanationLabel.text = [CMMatchExplanation summaryStringFromComponents:components];
    } else {
        self.explanationLabel.text = @"No explanation available";
    }

    self.metricsLabel.text = [NSString stringWithFormat:@"Detour: %.1f mi | Time overlap: %.0f min",
                              candidate.detourMiles, candidate.timeOverlapMinutes];
}

- (void)showSkeleton {
    self.rankLabel.text = @"--";
    self.orderRefLabel.text = @"Loading...";
    self.scoreLabel.text = @"";
    self.explanationLabel.text = @"";
    self.metricsLabel.text = @"";
    self.rankLabel.textColor = [UIColor tertiaryLabelColor];
}

@end

#pragma mark - Match List VC

@interface CMMatchListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) CMItinerary *itinerary;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) NSArray<CMMatchCandidate *> *candidates;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *orderRefCache;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL wasTruncated;
@end

@implementation CMMatchListViewController

- (instancetype)initWithItinerary:(CMItinerary *)itinerary {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _itinerary = itinerary;
        _candidates = @[];
        _orderRefCache = @{};
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Match Candidates";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupTableView];
    [self setupHintLabel];
    [self registerNotifications];
    [self loadCandidates];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 110;
    [_tableView registerClass:[CMMatchCell class] forCellReuseIdentifier:kMatchCellId];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.accessibilityLabel = @"Pull to recompute matches";
    [refresh addTarget:self action:@selector(triggerRecompute) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
    ]];
}

- (void)setupHintLabel {
    _hintLabel = [[UILabel alloc] init];
    _hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _hintLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _hintLabel.adjustsFontForContentSizeCategory = YES;
    _hintLabel.textColor = [UIColor systemOrangeColor];
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    _hintLabel.numberOfLines = 0;
    _hintLabel.text = @"";
    _hintLabel.hidden = YES;

    [self.view addSubview:_hintLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_hintLabel.topAnchor constraintEqualToAnchor:_tableView.bottomAnchor constant:4],
        [_hintLabel.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_hintLabel.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [_hintLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-4],
    ]];
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRecomputeNotification:)
                                                 name:CMMatchEngineDidRecomputeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleTruncatedNotification:)
                                                 name:CMMatchEngineTruncatedNotification
                                               object:nil];
}

- (void)handleRecomputeNotification:(NSNotification *)note {
    NSString *itinId = note.userInfo[@"itineraryId"];
    if ([itinId isEqualToString:self.itinerary.itineraryId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadCandidates];
        });
    }
}

- (void)handleTruncatedNotification:(NSNotification *)note {
    NSString *itinId = note.userInfo[@"itineraryId"];
    if ([itinId isEqualToString:self.itinerary.itineraryId]) {
        self.wasTruncated = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.hintLabel.text = @"Results truncated. Refine your itinerary for better matches.";
            self.hintLabel.hidden = NO;
        });
    }
}

- (void)loadCandidates {
    NSError *error = nil;
    NSArray<CMMatchCandidate *> *results = [[CMMatchEngine shared] rankCandidatesForItinerary:self.itinerary.itineraryId error:&error];
    if (results) {
        self.candidates = results;
        [self preloadOrderRefs];
    } else {
        self.candidates = @[];
    }
    self.isLoading = NO;
    [self.tableView reloadData];
}

- (void)preloadOrderRefs {
    CMOrderRepository *orderRepo = [[CMOrderRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    NSMutableDictionary<NSString *, NSString *> *refs = [NSMutableDictionary dictionary];
    for (CMMatchCandidate *c in self.candidates) {
        NSError *err = nil;
        CMOrder *order = [orderRepo findByOrderId:c.orderId error:&err];
        if (order.externalOrderRef) {
            refs[c.orderId] = order.externalOrderRef;
        }
    }
    self.orderRefCache = [refs copy];
}

- (void)triggerRecompute {
    self.isLoading = YES;
    [self.tableView reloadData];
    [CMHaptics selectionChanged];

    [[CMMatchEngine shared] recomputeCandidatesForItinerary:self.itinerary completion:^(NSError * _Nullable err) {
        [self.tableView.refreshControl endRefreshing];
        if (err) {
            [CMHaptics error];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Recompute Error"
                                                                           message:err.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [CMHaptics success];
        }
        [self loadCandidates];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isLoading) {
        return 5; // skeleton rows
    }
    return (NSInteger)self.candidates.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CMMatchCell *cell = [tableView dequeueReusableCellWithIdentifier:kMatchCellId forIndexPath:indexPath];

    if (self.isLoading) {
        [cell showSkeleton];
        return cell;
    }

    CMMatchCandidate *candidate = self.candidates[indexPath.row];
    NSString *ref = self.orderRefCache[candidate.orderId];
    [cell configureWithCandidate:candidate orderRef:ref];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
