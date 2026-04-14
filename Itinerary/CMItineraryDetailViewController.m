//
//  CMItineraryDetailViewController.m
//  CourierMatch
//

#import "CMItineraryDetailViewController.h"
#import "CMItineraryFormViewController.h"
#import "CMItinerary.h"
#import "CMAddress.h"
#import "CMDateFormatters.h"

static NSString * const kDetailCellId = @"DetailCell";
static NSString * const kStopCellId = @"StopCell";

typedef NS_ENUM(NSInteger, CMItineraryDetailSection) {
    CMItineraryDetailSectionRoute = 0,
    CMItineraryDetailSectionTime,
    CMItineraryDetailSectionVehicle,
    CMItineraryDetailSectionStops,
    CMItineraryDetailSectionCount
};

@interface CMItineraryDetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) CMItinerary *itinerary;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation CMItineraryDetailViewController

- (instancetype)initWithItinerary:(CMItinerary *)itinerary {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _itinerary = itinerary;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Itinerary Details";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                          target:self
                                                                                          action:@selector(editTapped)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Edit itinerary";

    [self setupTableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 50;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kDetailCellId];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kStopCellId];

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (NSString *)formatAddress:(CMAddress *)address {
    if (!address) return @"Not set";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (address.line1.length) [parts addObject:address.line1];
    if (address.line2.length) [parts addObject:address.line2];
    NSMutableString *cityLine = [NSMutableString string];
    if (address.city.length) [cityLine appendString:address.city];
    if (address.stateAbbr.length) [cityLine appendFormat:@", %@", address.stateAbbr];
    if (address.zip.length) [cityLine appendFormat:@" %@", address.zip];
    if (cityLine.length) [parts addObject:cityLine];
    return parts.count > 0 ? [parts componentsJoinedByString:@"\n"] : @"Not set";
}

#pragma mark - Actions

- (void)editTapped {
    CMItineraryFormViewController *formVC = [[CMItineraryFormViewController alloc] initWithItinerary:self.itinerary];
    [self.navigationController pushViewController:formVC animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CMItineraryDetailSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((CMItineraryDetailSection)section) {
        case CMItineraryDetailSectionRoute: return @"Route";
        case CMItineraryDetailSectionTime: return @"Departure Window";
        case CMItineraryDetailSectionVehicle: return @"Vehicle";
        case CMItineraryDetailSectionStops: return @"On-the-Way Stops";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((CMItineraryDetailSection)section) {
        case CMItineraryDetailSectionRoute: return 2; // origin, dest
        case CMItineraryDetailSectionTime: return 2; // start, end
        case CMItineraryDetailSectionVehicle: return 3; // type, capacity vol, capacity wt
        case CMItineraryDetailSectionStops: {
            NSInteger count = (NSInteger)self.itinerary.onTheWayStops.count;
            return count > 0 ? count : 1; // "No stops" row
        }
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;

    switch ((CMItineraryDetailSection)indexPath.section) {
        case CMItineraryDetailSectionRoute: {
            cell = [tableView dequeueReusableCellWithIdentifier:kDetailCellId forIndexPath:indexPath];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            if (indexPath.row == 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"Origin:\n%@", [self formatAddress:self.itinerary.originAddress]];
                cell.accessibilityLabel = [NSString stringWithFormat:@"Origin: %@", [self formatAddress:self.itinerary.originAddress]];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"Destination:\n%@", [self formatAddress:self.itinerary.destinationAddress]];
                cell.accessibilityLabel = [NSString stringWithFormat:@"Destination: %@", [self formatAddress:self.itinerary.destinationAddress]];
            }
            break;
        }
        case CMItineraryDetailSectionTime: {
            cell = [tableView dequeueReusableCellWithIdentifier:kDetailCellId forIndexPath:indexPath];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
            NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
            if (indexPath.row == 0) {
                NSString *dateStr = self.itinerary.departureWindowStart ? [dateFmt stringFromDate:self.itinerary.departureWindowStart] : @"--";
                NSString *timeStr = self.itinerary.departureWindowStart ? [timeFmt stringFromDate:self.itinerary.departureWindowStart] : @"--";
                cell.textLabel.text = [NSString stringWithFormat:@"Start: %@ %@", dateStr, timeStr];
            } else {
                NSString *dateStr = self.itinerary.departureWindowEnd ? [dateFmt stringFromDate:self.itinerary.departureWindowEnd] : @"--";
                NSString *timeStr = self.itinerary.departureWindowEnd ? [timeFmt stringFromDate:self.itinerary.departureWindowEnd] : @"--";
                cell.textLabel.text = [NSString stringWithFormat:@"End: %@ %@", dateStr, timeStr];
            }
            break;
        }
        case CMItineraryDetailSectionVehicle: {
            cell = [tableView dequeueReusableCellWithIdentifier:kDetailCellId forIndexPath:indexPath];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            if (indexPath.row == 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"Type: %@", self.itinerary.vehicleType ?: @"N/A"];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = [NSString stringWithFormat:@"Capacity (Volume): %.1f L", self.itinerary.vehicleCapacityVolumeL];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"Capacity (Weight): %.1f kg", self.itinerary.vehicleCapacityWeightKg];
            }
            break;
        }
        case CMItineraryDetailSectionStops: {
            cell = [tableView dequeueReusableCellWithIdentifier:kStopCellId forIndexPath:indexPath];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textColor = [UIColor labelColor];
            NSArray<CMAddress *> *stops = self.itinerary.onTheWayStops;
            if (stops.count == 0) {
                cell.textLabel.text = @"No stops";
                cell.textLabel.textColor = [UIColor tertiaryLabelColor];
            } else {
                CMAddress *stop = stops[indexPath.row];
                cell.textLabel.text = [NSString stringWithFormat:@"Stop %ld: %@", (long)(indexPath.row + 1), [self formatAddress:stop]];
            }
            break;
        }
        default:
            cell = [tableView dequeueReusableCellWithIdentifier:kDetailCellId forIndexPath:indexPath];
            break;
    }

    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
