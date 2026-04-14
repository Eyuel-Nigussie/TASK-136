//
//  CMScorecardListViewController.m
//  CourierMatch
//

#import "CMScorecardListViewController.h"
#import "CMScorecardViewController.h"
#import "CMDeliveryScorecard.h"
#import "CMOrder.h"
#import "CMOrderRepository.h"
#import "CMScorecardRepository.h"
#import "CMScoringEngine.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMHaptics.h"
#import "CMUserAccount.h"

static NSString * const kScorecardCellId = @"ScorecardListCell";

#pragma mark - Row model

@interface CMScorecardListRow : NSObject
@property (nonatomic, strong) CMOrder *order;
@property (nonatomic, strong, nullable) CMDeliveryScorecard *scorecard;
@end

@implementation CMScorecardListRow
@end

#pragma mark - Cell

@interface CMScorecardListCell : UITableViewCell
@property (nonatomic, strong) UILabel *orderRefLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *pointsLabel;
@end

@implementation CMScorecardListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.backgroundColor = [UIColor systemBackgroundColor];

        _orderRefLabel = [[UILabel alloc] init];
        _orderRefLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _orderRefLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _orderRefLabel.adjustsFontForContentSizeCategory = YES;
        _orderRefLabel.textColor = [UIColor labelColor];
        _orderRefLabel.numberOfLines = 1;

        _statusLabel = [[UILabel alloc] init];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        _statusLabel.adjustsFontForContentSizeCategory = YES;
        _statusLabel.textColor = [UIColor secondaryLabelColor];
        _statusLabel.numberOfLines = 1;

        _pointsLabel = [[UILabel alloc] init];
        _pointsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _pointsLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _pointsLabel.adjustsFontForContentSizeCategory = YES;
        _pointsLabel.textColor = [UIColor secondaryLabelColor];
        _pointsLabel.textAlignment = NSTextAlignmentRight;
        _pointsLabel.numberOfLines = 1;

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[
            _orderRefLabel, _statusLabel
        ]];
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 4;

        [self.contentView addSubview:textStack];
        [self.contentView addSubview:_pointsLabel];

        [NSLayoutConstraint activateConstraints:@[
            [textStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [textStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [textStack.trailingAnchor constraintEqualToAnchor:_pointsLabel.leadingAnchor constant:-12],
            [textStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],

            [_pointsLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [_pointsLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_pointsLabel.widthAnchor constraintGreaterThanOrEqualToConstant:80],
        ]];
    }
    return self;
}

- (void)configureWithRow:(CMScorecardListRow *)row {
    NSString *ref = row.order.externalOrderRef ?: row.order.orderId;
    self.orderRefLabel.text = ref;
    self.orderRefLabel.accessibilityLabel = [NSString stringWithFormat:@"Order %@", ref];

    if (!row.scorecard) {
        self.statusLabel.text = @"Not Started";
        self.statusLabel.textColor = [UIColor systemOrangeColor];
        self.pointsLabel.text = @"--";
        self.accessibilityValue = @"Scorecard not started";
    } else if ([row.scorecard isFinalized]) {
        self.statusLabel.text = @"Finalized";
        self.statusLabel.textColor = [UIColor systemGreenColor];
        self.pointsLabel.text = [NSString stringWithFormat:@"%.0f / %.0f",
                                 row.scorecard.totalPoints, row.scorecard.maxPoints];
        self.accessibilityValue = [NSString stringWithFormat:@"Finalized, %.0f of %.0f points",
                                   row.scorecard.totalPoints, row.scorecard.maxPoints];
    } else {
        self.statusLabel.text = @"In Progress";
        self.statusLabel.textColor = [UIColor systemBlueColor];
        self.pointsLabel.text = [NSString stringWithFormat:@"%.0f / %.0f",
                                 row.scorecard.totalPoints, row.scorecard.maxPoints];
        self.accessibilityValue = [NSString stringWithFormat:@"In progress, %.0f of %.0f points",
                                   row.scorecard.totalPoints, row.scorecard.maxPoints];
    }
}

@end

#pragma mark - List VC

@interface CMScorecardListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray<CMScorecardListRow *> *rows;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation CMScorecardListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Scoring";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.rows = @[];

    [self setupTableView];
    [self setupEmptyLabel];
    [self loadData];
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
    _tableView.estimatedRowHeight = 72;
    [_tableView registerClass:[CMScorecardListCell class] forCellReuseIdentifier:kScorecardCellId];

    _refreshControl = [[UIRefreshControl alloc] init];
    _refreshControl.accessibilityLabel = @"Pull to refresh scorecards";
    [_refreshControl addTarget:self action:@selector(handlePullToRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (void)setupEmptyLabel {
    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.text = @"No delivered orders to score.";
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _emptyLabel.adjustsFontForContentSizeCategory = YES;
    _emptyLabel.textColor = [UIColor secondaryLabelColor];
    _emptyLabel.hidden = YES;
    _emptyLabel.accessibilityLabel = @"No delivered orders to score";

    [self.view addSubview:_emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.readableContentGuide.leadingAnchor],
        [_emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.readableContentGuide.trailingAnchor],
    ]];
}

- (void)loadData {
    NSManagedObjectContext *ctx = [CMCoreDataStack shared].viewContext;
    CMOrderRepository *orderRepo = [[CMOrderRepository alloc] initWithContext:ctx];
    CMScorecardRepository *scorecardRepo = [[CMScorecardRepository alloc] initWithContext:ctx];

    NSError *error = nil;
    NSArray<CMOrder *> *delivered = [orderRepo ordersWithStatus:CMOrderStatusDelivered
                                                         limit:500
                                                         error:&error];
    if (!delivered) {
        delivered = @[];
    }

    NSMutableArray<CMScorecardListRow *> *result = [NSMutableArray array];
    for (CMOrder *order in delivered) {
        CMScorecardListRow *row = [[CMScorecardListRow alloc] init];
        row.order = order;

        NSError *scErr = nil;
        CMDeliveryScorecard *sc = [scorecardRepo findForOrder:order.orderId error:&scErr];
        row.scorecard = sc;

        [result addObject:row];
    }

    self.rows = result;
    [self.tableView reloadData];
    self.emptyLabel.hidden = (self.rows.count > 0);
}

- (void)handlePullToRefresh {
    [CMHaptics selectionChanged];
    [self loadData];
    [self.refreshControl endRefreshing];
    [CMHaptics success];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CMScorecardListCell *cell = [tableView dequeueReusableCellWithIdentifier:kScorecardCellId forIndexPath:indexPath];
    CMScorecardListRow *row = self.rows[indexPath.row];
    [cell configureWithRow:row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CMScorecardListRow *row = self.rows[indexPath.row];

    if (row.scorecard) {
        // Push existing scorecard
        CMScorecardViewController *vc = [[CMScorecardViewController alloc] initWithScorecard:row.scorecard];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        // Create new scorecard
        NSManagedObjectContext *ctx = [CMCoreDataStack shared].viewContext;
        CMScoringEngine *engine = [[CMScoringEngine alloc] initWithContext:ctx];
        NSString *courierId = row.order.assignedCourierId ?: [CMTenantContext shared].currentUserId ?: @"";

        NSError *err = nil;
        CMDeliveryScorecard *sc = [engine createScorecardForOrder:row.order
                                                        courierId:courierId
                                                            error:&err];
        if (sc) {
            row.scorecard = sc;
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            CMScorecardViewController *vc = [[CMScorecardViewController alloc] initWithScorecard:sc];
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            [CMHaptics error];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                           message:err.localizedDescription ?: @"Failed to create scorecard."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

@end
