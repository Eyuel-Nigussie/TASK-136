//
//  CMNotificationListViewController.m
//  CourierMatch
//

#import "CMNotificationListViewController.h"
#import "CMNotificationItem.h"
#import "CMNotificationCenterService.h"
#import "CMTenantContext.h"
#import "CMDateFormatters.h"
#import "CMHaptics.h"

static NSString * const kNotifCellId = @"NotifCell";

#pragma mark - Notification Cell

@interface CMNotificationCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;
@property (nonatomic, strong) UILabel *timestampLabel;
@property (nonatomic, strong) UIView *unreadDot;
@property (nonatomic, strong) UILabel *childCountLabel;
@property (nonatomic, strong) UIButton *ackButton;
@property (nonatomic, copy) void (^ackHandler)(void);
@end

@implementation CMNotificationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

        _unreadDot = [[UIView alloc] init];
        _unreadDot.translatesAutoresizingMaskIntoConstraints = NO;
        _unreadDot.backgroundColor = [UIColor systemBlueColor];
        _unreadDot.layer.cornerRadius = 5;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        _titleLabel.adjustsFontForContentSizeCategory = YES;
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.numberOfLines = 2;

        _bodyLabel = [[UILabel alloc] init];
        _bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _bodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _bodyLabel.adjustsFontForContentSizeCategory = YES;
        _bodyLabel.textColor = [UIColor secondaryLabelColor];
        _bodyLabel.numberOfLines = 3;

        _timestampLabel = [[UILabel alloc] init];
        _timestampLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _timestampLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _timestampLabel.adjustsFontForContentSizeCategory = YES;
        _timestampLabel.textColor = [UIColor tertiaryLabelColor];

        _childCountLabel = [[UILabel alloc] init];
        _childCountLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _childCountLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _childCountLabel.adjustsFontForContentSizeCategory = YES;
        _childCountLabel.textColor = [UIColor systemOrangeColor];
        _childCountLabel.hidden = YES;

        _ackButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _ackButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_ackButton setTitle:@"Ack" forState:UIControlStateNormal];
        _ackButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        _ackButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        _ackButton.accessibilityLabel = @"Acknowledge notification";
        _ackButton.hidden = YES;
        [_ackButton addTarget:self action:@selector(ackButtonPressed) forControlEvents:UIControlEventTouchUpInside];

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _bodyLabel, _timestampLabel, _childCountLabel]];
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 3;

        [self.contentView addSubview:_unreadDot];
        [self.contentView addSubview:textStack];
        [self.contentView addSubview:_ackButton];

        [NSLayoutConstraint activateConstraints:@[
            [_unreadDot.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [_unreadDot.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_unreadDot.widthAnchor constraintEqualToConstant:10],
            [_unreadDot.heightAnchor constraintEqualToConstant:10],

            [textStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [textStack.leadingAnchor constraintEqualToAnchor:_unreadDot.trailingAnchor constant:8],
            [textStack.trailingAnchor constraintEqualToAnchor:_ackButton.leadingAnchor constant:-8],
            [textStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_ackButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_ackButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_ackButton.widthAnchor constraintGreaterThanOrEqualToConstant:44],
            [_ackButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        ]];
    }
    return self;
}

- (void)configureWithItem:(CMNotificationItem *)item showAck:(BOOL)showAck {
    self.titleLabel.text = item.renderedTitle ?: item.templateKey;
    self.bodyLabel.text = item.renderedBody ?: @"";

    NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
    NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
    self.timestampLabel.text = [NSString stringWithFormat:@"%@ %@",
                                [dateFmt stringFromDate:item.createdAt],
                                [timeFmt stringFromDate:item.createdAt]];

    // Unread indicator
    BOOL isUnread = (item.readAt == nil);
    self.unreadDot.hidden = !isUnread;
    self.titleLabel.font = isUnread ?
        [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] :
        [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];

    // Digest child count
    if (item.childIds.count > 0) {
        self.childCountLabel.text = [NSString stringWithFormat:@"%lu notifications in this digest", (unsigned long)item.childIds.count];
        self.childCountLabel.hidden = NO;
    } else {
        self.childCountLabel.hidden = YES;
    }

    // Ack button for dispatchers
    self.ackButton.hidden = !showAck || (item.ackedAt != nil);

    self.accessibilityLabel = [NSString stringWithFormat:@"%@ notification: %@. %@",
                               isUnread ? @"Unread" : @"Read",
                               item.renderedTitle ?: @"",
                               item.renderedBody ?: @""];
}

- (void)ackButtonPressed {
    if (self.ackHandler) {
        self.ackHandler();
    }
}

@end

#pragma mark - Notification List VC

@interface CMNotificationListViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<CMNotificationItem *> *notifications;
@property (nonatomic, strong) CMNotificationCenterService *notifService;
@property (nonatomic, assign) BOOL isDispatcher;
@end

@implementation CMNotificationListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Notifications";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.notifService = [[CMNotificationCenterService alloc] init];
    self.notifications = @[];
    self.isDispatcher = [[CMTenantContext shared].currentRole isEqualToString:@"dispatcher"];

    [self setupTableView];
    [self registerNotifications];
    [self loadData];
    [self updateBadge];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
    [self updateBadge];
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
    _tableView.estimatedRowHeight = 90;
    [_tableView registerClass:[CMNotificationCell class] forCellReuseIdentifier:kNotifCellId];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.accessibilityLabel = @"Pull to refresh notifications";
    [refresh addTarget:self action:@selector(handleRefresh) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = refresh;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(unreadCountChanged:)
                                                 name:CMNotificationUnreadCountDidChangeNotification
                                               object:nil];
}

- (void)unreadCountChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadData];
        [self updateBadge];
    });
}

- (void)handleRefresh {
    [self loadData];
    [self.tableView.refreshControl endRefreshing];
}

- (void)loadData {
    NSError *error = nil;
    NSArray<CMNotificationItem *> *items = [self.notifService unreadNotificationsForCurrentUser:0 error:&error];
    self.notifications = items ?: @[];
    [self.tableView reloadData];
}

- (void)updateBadge {
    NSUInteger unread = [self.notifService unreadCountForCurrentUser];
    if (unread > 0) {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%lu", (unsigned long)unread];
    } else {
        self.tabBarItem.badgeValue = nil;
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.notifications.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CMNotificationCell *cell = [tableView dequeueReusableCellWithIdentifier:kNotifCellId forIndexPath:indexPath];
    CMNotificationItem *item = self.notifications[indexPath.row];
    [cell configureWithItem:item showAck:self.isDispatcher];

    __weak typeof(self) weakSelf = self;
    cell.ackHandler = ^{
        NSError *err = nil;
        [weakSelf.notifService markAcknowledged:item.notificationId error:&err];
        if (!err) {
            [CMHaptics success];
            [weakSelf loadData];
            [weakSelf updateBadge];
        } else {
            [CMHaptics error];
        }
    };

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CMNotificationItem *item = self.notifications[indexPath.row];

    // Mark as read
    NSError *error = nil;
    [self.notifService markRead:item.notificationId error:&error];
    [self loadData];
    [self updateBadge];
}

@end
