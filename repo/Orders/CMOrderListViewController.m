//
//  CMOrderListViewController.m
//  CourierMatch
//

#import "CMOrderListViewController.h"
#import "CMOrder.h"
#import "CMOrderDetailViewController.h"
#import "CMOrderRepository.h"
#import "CMCoreDataStack.h"
#import "CMAddress.h"
#import "CMDateFormatters.h"
#import "CMHaptics.h"
#import "CMTenantContext.h"
#import "CMUserAccount.h"
#import "CMPermissionMatrix.h"

static NSString * const kOrderCellId = @"OrderCell";

typedef NS_ENUM(NSInteger, CMOrderFilter) {
    CMOrderFilterNew = 0,
    CMOrderFilterAssigned,
    CMOrderFilterDelivered,
    CMOrderFilterAll
};

#pragma mark - Order Cell

@interface CMOrderCell : UITableViewCell
@property (nonatomic, strong) UILabel *refLabel;
@property (nonatomic, strong) UILabel *routeLabel;
@property (nonatomic, strong) UILabel *windowLabel;
@property (nonatomic, strong) UILabel *statusBadge;
@end

@implementation CMOrderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        self.backgroundColor = [UIColor systemBackgroundColor];

        _refLabel = [[UILabel alloc] init];
        _refLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _refLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _refLabel.adjustsFontForContentSizeCategory = YES;
        _refLabel.textColor = [UIColor labelColor];

        _routeLabel = [[UILabel alloc] init];
        _routeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _routeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        _routeLabel.adjustsFontForContentSizeCategory = YES;
        _routeLabel.textColor = [UIColor secondaryLabelColor];

        _windowLabel = [[UILabel alloc] init];
        _windowLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _windowLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _windowLabel.adjustsFontForContentSizeCategory = YES;
        _windowLabel.textColor = [UIColor tertiaryLabelColor];

        _statusBadge = [[UILabel alloc] init];
        _statusBadge.translatesAutoresizingMaskIntoConstraints = NO;
        _statusBadge.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _statusBadge.adjustsFontForContentSizeCategory = YES;
        _statusBadge.textAlignment = NSTextAlignmentCenter;
        _statusBadge.layer.cornerRadius = 6;
        _statusBadge.layer.masksToBounds = YES;
        _statusBadge.textColor = [UIColor whiteColor];

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_refLabel, _routeLabel, _windowLabel]];
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 3;

        [self.contentView addSubview:textStack];
        [self.contentView addSubview:_statusBadge];

        [NSLayoutConstraint activateConstraints:@[
            [textStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [textStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [textStack.trailingAnchor constraintEqualToAnchor:_statusBadge.leadingAnchor constant:-12],
            [textStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_statusBadge.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [_statusBadge.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_statusBadge.widthAnchor constraintGreaterThanOrEqualToConstant:72],
            [_statusBadge.heightAnchor constraintGreaterThanOrEqualToConstant:24],
        ]];
    }
    return self;
}

- (void)configureWithOrder:(CMOrder *)order {
    self.refLabel.text = order.externalOrderRef ?: order.orderId;
    self.refLabel.accessibilityLabel = [NSString stringWithFormat:@"Order %@", order.externalOrderRef ?: order.orderId];

    NSString *pickup = order.pickupAddress.city ?: @"Unknown";
    NSString *dropoff = order.dropoffAddress.city ?: @"Unknown";
    self.routeLabel.text = [NSString stringWithFormat:@"%@ \u2192 %@", pickup, dropoff];

    NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
    NSString *startStr = order.pickupWindowStart ? [timeFmt stringFromDate:order.pickupWindowStart] : @"--";
    NSString *endStr = order.pickupWindowEnd ? [timeFmt stringFromDate:order.pickupWindowEnd] : @"--";
    self.windowLabel.text = [NSString stringWithFormat:@"Pickup: %@ - %@", startStr, endStr];

    self.statusBadge.text = [NSString stringWithFormat:@" %@ ", order.status ?: @"--"];
    self.statusBadge.accessibilityLabel = [NSString stringWithFormat:@"Status: %@", order.status];

    if ([order.status isEqualToString:CMOrderStatusNew]) {
        self.statusBadge.backgroundColor = [UIColor systemBlueColor];
    } else if ([order.status isEqualToString:CMOrderStatusAssigned]) {
        self.statusBadge.backgroundColor = [UIColor systemOrangeColor];
    } else if ([order.status isEqualToString:CMOrderStatusDelivered]) {
        self.statusBadge.backgroundColor = [UIColor systemGreenColor];
    } else if ([order.status isEqualToString:CMOrderStatusDisputed]) {
        self.statusBadge.backgroundColor = [UIColor systemRedColor];
    } else {
        self.statusBadge.backgroundColor = [UIColor systemGrayColor];
    }
}

@end

#pragma mark - Order List VC

@interface CMOrderListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<CMOrder *> *orders;
@property (nonatomic, strong) CMOrderRepository *repository;
@property (nonatomic, assign) CMOrderFilter currentFilter;
@end

@implementation CMOrderListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Orders";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.repository = [[CMOrderRepository alloc] initWithContext:[CMCoreDataStack shared].viewContext];
    self.orders = @[];
    self.currentFilter = CMOrderFilterAll;

    [self setupSegmentControl];
    [self setupTableView];
    [self loadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
}

- (void)setupSegmentControl {
    _segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"New", @"Assigned", @"Delivered", @"All"]];
    _segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    _segmentControl.selectedSegmentIndex = 3; // All by default
    [_segmentControl addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged];
    _segmentControl.accessibilityLabel = @"Filter orders by status";

    [self.view addSubview:_segmentControl];
    [NSLayoutConstraint activateConstraints:@[
        [_segmentControl.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [_segmentControl.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_segmentControl.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [_segmentControl.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 80;
    [_tableView registerClass:[CMOrderCell class] forCellReuseIdentifier:kOrderCellId];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.accessibilityLabel = @"Pull to refresh orders";
    [refresh addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:_segmentControl.bottomAnchor constant:8],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (void)filterChanged:(UISegmentedControl *)sender {
    [CMHaptics selectionChanged];
    self.currentFilter = (CMOrderFilter)sender.selectedSegmentIndex;
    [self loadData];
}

- (void)handleRefresh {
    [self loadData];
    [self.tableView.refreshControl endRefreshing];
}

- (void)loadData {
    NSError *error = nil;
    NSString *statusFilter = nil;

    switch (self.currentFilter) {
        case CMOrderFilterNew:
            statusFilter = CMOrderStatusNew;
            break;
        case CMOrderFilterAssigned:
            statusFilter = CMOrderStatusAssigned;
            break;
        case CMOrderFilterDelivered:
            statusFilter = CMOrderStatusDelivered;
            break;
        case CMOrderFilterAll:
        default:
            statusFilter = nil;
            break;
    }

    NSArray<CMOrder *> *fetched = nil;
    if (statusFilter) {
        fetched = [self.repository ordersWithStatus:statusFilter limit:200 error:&error] ?: @[];
    } else {
        // All orders: fetch all statuses
        NSMutableArray *all = [NSMutableArray array];
        for (NSString *status in @[CMOrderStatusNew, CMOrderStatusAssigned, CMOrderStatusPickedUp,
                                   CMOrderStatusDelivered, CMOrderStatusDisputed, CMOrderStatusCancelled]) {
            NSArray *batch = [self.repository ordersWithStatus:status limit:200 error:&error];
            if (batch) [all addObjectsFromArray:batch];
        }
        // Sort by createdAt descending
        [all sortUsingComparator:^NSComparisonResult(CMOrder *a, CMOrder *b) {
            return [b.createdAt compare:a.createdAt];
        }];
        fetched = [all copy];
    }

    // Object-level RBAC: couriers only see orders assigned to them or unassigned (new)
    NSString *role = [CMTenantContext shared].currentRole;
    if ([role isEqualToString:CMUserRoleCourier]) {
        NSString *currentUserId = [CMTenantContext shared].currentUserId;
        NSMutableArray<CMOrder *> *filtered = [NSMutableArray array];
        for (CMOrder *order in fetched) {
            BOOL isNew = [order.status isEqualToString:CMOrderStatusNew];
            BOOL isAssignedToMe = (currentUserId && [order.assignedCourierId isEqualToString:currentUserId]);
            if (isNew || isAssignedToMe) {
                [filtered addObject:order];
            }
        }
        self.orders = [filtered copy];
    } else {
        // Dispatchers, CS, admin, etc. see all orders
        self.orders = fetched;
    }

    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.orders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CMOrderCell *cell = [tableView dequeueReusableCellWithIdentifier:kOrderCellId forIndexPath:indexPath];
    [cell configureWithOrder:self.orders[indexPath.row]];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CMOrder *order = self.orders[indexPath.row];
    CMOrderDetailViewController *detail = [[CMOrderDetailViewController alloc] initWithOrder:order];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
