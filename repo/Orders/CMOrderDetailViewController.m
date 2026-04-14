//
//  CMOrderDetailViewController.m
//  CourierMatch
//

#import "CMOrderDetailViewController.h"
#import "CMOrder.h"
#import "CMAddress.h"
#import "CMDateFormatters.h"
#import "CMIDMasker.h"
#import "CMTenantContext.h"
#import "CMNotificationCenterService.h"
#import "CMDisputeIntakeViewController.h"
#import "CMCameraCaptureViewController.h"
#import "CMAttachment.h"
#import "CMHaptics.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"
#import "CMBiometricAuth.h"
#import "CMAuditService.h"
#import "CMPermissionMatrix.h"
#import "CMSaveWithVersionCheckPolicy+UI.h"

typedef NS_ENUM(NSInteger, CMOrderDetailSection) {
    CMOrderDetailSectionStatus = 0,
    CMOrderDetailSectionAddresses,
    CMOrderDetailSectionWindows,
    CMOrderDetailSectionParcel,
    CMOrderDetailSectionCustomer,
    CMOrderDetailSectionActions,
    CMOrderDetailSectionCount
};

@interface CMOrderDetailViewController () <UITableViewDataSource, UITableViewDelegate, CMCameraCaptureDelegate>
@property (nonatomic, strong) CMOrder *order;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL customerNotesRevealed;
@property (nonatomic, assign) BOOL customerIdRevealed;
@property (nonatomic, assign) int64_t baseVersion;
@end

@implementation CMOrderDetailViewController

- (instancetype)initWithOrder:(CMOrder *)order {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _order = order;
        _customerNotesRevealed = NO;
        _customerIdRevealed = NO;
        _baseVersion = order.version;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Order Detail";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupTableView];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 50;
    _tableView.allowsSelection = YES;

    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];
}

- (NSString *)formatAddress:(CMAddress *)addr {
    if (!addr) return @"Not set";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (addr.line1.length) [parts addObject:addr.line1];
    if (addr.line2.length) [parts addObject:addr.line2];
    NSMutableString *cityLine = [NSMutableString string];
    if (addr.city.length) [cityLine appendString:addr.city];
    if (addr.stateAbbr.length) [cityLine appendFormat:@", %@", addr.stateAbbr];
    if (addr.zip.length) [cityLine appendFormat:@" %@", addr.zip];
    if (cityLine.length) [parts addObject:cityLine];
    return parts.count > 0 ? [parts componentsJoinedByString:@"\n"] : @"Not set";
}

- (NSString *)maskedCustomerNotes {
    if (self.customerNotesRevealed) {
        return self.order.customerNotes ?: @"None";
    }
    NSString *notes = self.order.customerNotes;
    if (!notes || notes.length == 0) return @"None";
    return [CMIDMasker maskTrailing:notes visibleTail:4];
}

- (NSString *)maskedCustomerId {
    if (self.customerIdRevealed) {
        NSData *data = self.order.sensitiveCustomerId;
        if (!data) return @"N/A";
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"N/A";
    }
    NSData *data = self.order.sensitiveCustomerId;
    if (!data) return @"N/A";
    NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!raw) return @"N/A";
    return [CMIDMasker maskTrailing:raw visibleTail:4];
}

#pragma mark - Actions

- (void)assignTapped {
    // Function-level authorization: only dispatchers with orders.assign permission
    NSString *role = [CMTenantContext shared].currentRole;
    if (![[CMPermissionMatrix shared] hasPermission:@"orders.assign" forRole:role]) {
        [self showPermissionDenied]; return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Assign Courier"
                                                                  message:@"Enter courier ID to assign"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Courier ID";
        tf.accessibilityLabel = @"Courier ID";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Assign" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *courierId = alert.textFields.firstObject.text;
        if (courierId.length == 0) return;

        NSDictionary *changes = @{
            @"assignedCourierId": courierId,
            @"status": CMOrderStatusAssigned,
            @"updatedAt": [NSDate date]
        };

        [CMSaveWithVersionCheckPolicy saveChanges:changes
                                         toObject:self.order
                                      baseVersion:self.baseVersion
                              fromViewController:self
                                       completion:^(BOOL saved) {
            if (saved) {
                self.baseVersion = self.order.version;

                // Emit assignment notification
                CMNotificationCenterService *notifService = [[CMNotificationCenterService alloc] init];
                [notifService emitNotificationForEvent:@"assigned"
                                               payload:@{@"orderRef": self.order.externalOrderRef ?: @"",
                                                         @"courierName": courierId}
                                       recipientUserId:courierId
                                     subjectEntityType:@"Order"
                                       subjectEntityId:self.order.orderId
                                            completion:nil];

                [CMHaptics success];
                [self.tableView reloadData];
            }
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateStatusTapped {
    // Function-level authorization: courier can only update own orders
    NSString *role = [CMTenantContext shared].currentRole;
    if (![[CMPermissionMatrix shared] hasPermission:@"orders.update_status_own" forRole:role]) {
        [self showPermissionDenied]; return;
    }
    // Courier must be the assigned courier — no empty/nil bypass.
    NSString *currentUserId = [CMTenantContext shared].currentUserId;
    if ([role isEqualToString:CMUserRoleCourier]) {
        if (!self.order.assignedCourierId ||
            ![self.order.assignedCourierId isEqualToString:currentUserId]) {
            [self showPermissionDenied]; return;
        }
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Update Status"
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *statuses = @[CMOrderStatusPickedUp, CMOrderStatusDelivered, CMOrderStatusCancelled];
    for (NSString *status in statuses) {
        [sheet addAction:[UIAlertAction actionWithTitle:status style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *oldStatus = self.order.status;

            NSDictionary *changes = @{
                @"status": status,
                @"updatedAt": [NSDate date]
            };

            [CMSaveWithVersionCheckPolicy saveChanges:changes
                                             toObject:self.order
                                          baseVersion:self.baseVersion
                                  fromViewController:self
                                           completion:^(BOOL saved) {
                if (saved) {
                    self.baseVersion = self.order.version;

                    // Emit status-change notification
                    CMNotificationCenterService *notifService = [[CMNotificationCenterService alloc] init];
                    NSString *templateKey = [status isEqualToString:CMOrderStatusPickedUp] ? @"picked_up" :
                                            [status isEqualToString:CMOrderStatusDelivered] ? @"delivered" :
                                            [status isEqualToString:CMOrderStatusCancelled] ? @"cancelled" : @"assigned";
                    NSString *recipientId = self.order.assignedCourierId ?: [CMTenantContext shared].currentUserId ?: @"";
                    NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
                    NSString *nowFormatted = [timeFmt stringFromDate:[NSDate date]];
                    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:
                        @{@"orderRef": self.order.externalOrderRef ?: @""}];
                    if ([status isEqualToString:CMOrderStatusPickedUp]) {
                        payload[@"pickupTime"] = nowFormatted;
                    } else if ([status isEqualToString:CMOrderStatusDelivered]) {
                        payload[@"deliveredTime"] = nowFormatted;
                    }
                    [notifService emitNotificationForEvent:templateKey
                                                   payload:[payload copy]
                                           recipientUserId:recipientId
                                         subjectEntityType:@"Order"
                                           subjectEntityId:self.order.orderId
                                                completion:nil];

                    [CMHaptics success];
                    [self.tableView reloadData];
                }
            }];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openDisputeTapped {
    NSString *role = [CMTenantContext shared].currentRole;
    if (![[CMPermissionMatrix shared] hasPermission:@"disputes.open" forRole:role]) {
        [self showPermissionDenied]; return;
    }
    CMDisputeIntakeViewController *disputeVC = [[CMDisputeIntakeViewController alloc] initWithOrder:self.order];
    [self.navigationController pushViewController:disputeVC animated:YES];
}

- (void)capturePhotoTapped {
    CMCameraCaptureViewController *cameraVC = [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                                                              ownerId:self.order.orderId];
    cameraVC.delegate = self;
    [self presentViewController:cameraVC animated:YES completion:nil];
}

#pragma mark - CMCameraCaptureDelegate

- (void)cameraCaptureDidCaptureAttachment:(CMAttachment *)attachment {
    [CMHaptics success];
}

- (void)cameraCaptureDidCancel {
    // No action needed
}

- (void)editNotesTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Edit Notes"
                                                                  message:@"Update customer notes for this order."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = self.order.customerNotes ?: @"";
        tf.placeholder = @"Customer notes";
        tf.accessibilityLabel = @"Customer notes";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newNotes = alert.textFields.firstObject.text ?: @"";
        NSString *oldNotes = self.order.customerNotes ?: @"";

        if ([newNotes isEqualToString:oldNotes]) {
            return; // No change
        }

        NSDictionary *beforeJSON = @{ @"customerNotes": oldNotes };
        NSDictionary *changes = @{ @"customerNotes": newNotes };

        [CMSaveWithVersionCheckPolicy saveChanges:changes
                                         toObject:self.order
                                      baseVersion:self.baseVersion
                              fromViewController:self
                                       completion:^(BOOL saved) {
            if (!saved) {
                [CMHaptics error];
                return;
            }

            // Update baseVersion to reflect the saved version.
            NSNumber *curV = [self.order valueForKey:@"version"];
            self.baseVersion = curV ? curV.longLongValue : self.baseVersion;

            // Write audit entry
            NSDictionary *afterJSON = @{ @"customerNotes": self.order.customerNotes ?: @"" };
            [[CMAuditService shared] recordAction:@"order.notes_edited"
                                       targetType:@"Order"
                                         targetId:self.order.orderId
                                       beforeJSON:beforeJSON
                                        afterJSON:afterJSON
                                           reason:@"Customer service edited order notes"
                                       completion:nil];

            [CMHaptics success];

            // Reload the customer notes row
            NSIndexPath *notesIP = [NSIndexPath indexPathForRow:0 inSection:CMOrderDetailSectionCustomer];
            [self.tableView reloadRowsAtIndexPaths:@[notesIP] withRowAnimation:UITableViewRowAnimationFade];
        }];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CMOrderDetailSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((CMOrderDetailSection)section) {
        case CMOrderDetailSectionStatus: return @"Status";
        case CMOrderDetailSectionAddresses: return @"Addresses";
        case CMOrderDetailSectionWindows: return @"Time Windows";
        case CMOrderDetailSectionParcel: return @"Parcel";
        case CMOrderDetailSectionCustomer: return @"Customer Info";
        case CMOrderDetailSectionActions: return @"Actions";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((CMOrderDetailSection)section) {
        case CMOrderDetailSectionStatus: return 3; // ref, status, assigned
        case CMOrderDetailSectionAddresses: return 2; // pickup, dropoff
        case CMOrderDetailSectionWindows: return 2; // pickup window, dropoff window
        case CMOrderDetailSectionParcel: return 2; // vol, weight
        case CMOrderDetailSectionCustomer: return 2; // notes, customer id
        case CMOrderDetailSectionActions: {
            NSString *role = [CMTenantContext shared].currentRole;
            CMPermissionMatrix *pm = [CMPermissionMatrix shared];
            NSInteger count = 0;
            if ([pm hasPermission:@"orders.assign" forRole:role]) count++; // Assign
            if ([pm hasPermission:@"orders.update_status_own" forRole:role]) count++; // Update Status
            if ([pm hasPermission:@"orders.edit_notes" forRole:role]) count++; // Edit Notes
            if ([pm hasPermission:@"disputes.open" forRole:role]) count++; // Open Dispute
            if ([pm hasPermission:@"attachments.upload_own" forRole:role] ||
                [pm hasPermission:@"attachments.upload_dispute" forRole:role]) count++; // Capture Photo
            return MAX(count, 1); // at least show something
        }
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.numberOfLines = 0;

    NSDateFormatter *timeFmt = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
    NSDateFormatter *dateFmt = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];

    switch ((CMOrderDetailSection)indexPath.section) {
        case CMOrderDetailSectionStatus: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Order Ref";
                cell.detailTextLabel.text = self.order.externalOrderRef ?: self.order.orderId;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Status";
                cell.detailTextLabel.text = self.order.status;
            } else {
                cell.textLabel.text = @"Assigned Courier";
                cell.detailTextLabel.text = self.order.assignedCourierId ?: @"Unassigned";
            }
            break;
        }
        case CMOrderDetailSectionAddresses: {
            if (indexPath.row == 0) {
                cell.textLabel.text = [NSString stringWithFormat:@"Pickup:\n%@", [self formatAddress:self.order.pickupAddress]];
            } else {
                cell.textLabel.text = [NSString stringWithFormat:@"Dropoff:\n%@", [self formatAddress:self.order.dropoffAddress]];
            }
            break;
        }
        case CMOrderDetailSectionWindows: {
            if (indexPath.row == 0) {
                NSString *start = self.order.pickupWindowStart ? [NSString stringWithFormat:@"%@ %@", [dateFmt stringFromDate:self.order.pickupWindowStart], [timeFmt stringFromDate:self.order.pickupWindowStart]] : @"--";
                NSString *end = self.order.pickupWindowEnd ? [NSString stringWithFormat:@"%@ %@", [dateFmt stringFromDate:self.order.pickupWindowEnd], [timeFmt stringFromDate:self.order.pickupWindowEnd]] : @"--";
                cell.textLabel.text = @"Pickup Window";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", start, end];
            } else {
                NSString *start = self.order.dropoffWindowStart ? [NSString stringWithFormat:@"%@ %@", [dateFmt stringFromDate:self.order.dropoffWindowStart], [timeFmt stringFromDate:self.order.dropoffWindowStart]] : @"--";
                NSString *end = self.order.dropoffWindowEnd ? [NSString stringWithFormat:@"%@ %@", [dateFmt stringFromDate:self.order.dropoffWindowEnd], [timeFmt stringFromDate:self.order.dropoffWindowEnd]] : @"--";
                cell.textLabel.text = @"Dropoff Window";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ - %@", start, end];
            }
            break;
        }
        case CMOrderDetailSectionParcel: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Volume";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f L", self.order.parcelVolumeL];
            } else {
                cell.textLabel.text = @"Weight";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f kg", self.order.parcelWeightKg];
            }
            break;
        }
        case CMOrderDetailSectionCustomer: {
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Customer Notes";
                cell.detailTextLabel.text = [self maskedCustomerNotes];
                cell.accessibilityLabel = @"Customer notes (tap to reveal)";
                cell.accessibilityHint = self.customerNotesRevealed ? @"Notes are revealed" : @"Double tap to reveal masked notes";
            } else {
                cell.textLabel.text = @"Customer ID";
                cell.detailTextLabel.text = [self maskedCustomerId];
                cell.accessibilityLabel = @"Customer ID (tap to reveal)";
                cell.accessibilityHint = self.customerIdRevealed ? @"ID is revealed" : @"Double tap to reveal masked ID";
            }
            break;
        }
        case CMOrderDetailSectionActions: {
            NSString *role = [CMTenantContext shared].currentRole;
            CMPermissionMatrix *pm = [CMPermissionMatrix shared];
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.textColor = [UIColor systemBlueColor];

            // Build ordered list of available actions for this role
            NSMutableArray<NSString *> *actions = [NSMutableArray array];
            if ([pm hasPermission:@"orders.assign" forRole:role]) [actions addObject:@"assign"];
            if ([pm hasPermission:@"orders.update_status_own" forRole:role]) [actions addObject:@"update_status"];
            if ([pm hasPermission:@"orders.edit_notes" forRole:role]) [actions addObject:@"edit_notes"];
            if ([pm hasPermission:@"disputes.open" forRole:role]) [actions addObject:@"open_dispute"];
            if ([pm hasPermission:@"attachments.upload_own" forRole:role] ||
                [pm hasPermission:@"attachments.upload_dispute" forRole:role]) [actions addObject:@"capture_photo"];

            if (indexPath.row < (NSInteger)actions.count) {
                NSString *action = actions[indexPath.row];
                if ([action isEqualToString:@"assign"]) {
                    cell.textLabel.text = @"Assign Courier";
                    cell.accessibilityLabel = @"Assign courier to this order";
                } else if ([action isEqualToString:@"update_status"]) {
                    cell.textLabel.text = @"Update Status";
                    cell.accessibilityLabel = @"Update order status";
                } else if ([action isEqualToString:@"edit_notes"]) {
                    cell.textLabel.text = @"Edit Notes";
                    cell.accessibilityLabel = @"Edit customer notes for this order";
                } else if ([action isEqualToString:@"open_dispute"]) {
                    cell.textLabel.text = @"Open Dispute";
                    cell.accessibilityLabel = @"Open a dispute for this order";
                } else if ([action isEqualToString:@"capture_photo"]) {
                    cell.textLabel.text = @"Capture Photo";
                    cell.accessibilityLabel = @"Capture delivery proof photo";
                }
            } else {
                cell.textLabel.text = @"No actions available";
                cell.textLabel.textColor = [UIColor tertiaryLabelColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
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

    if (indexPath.section == CMOrderDetailSectionCustomer) {
        BOOL isNotes = (indexPath.row == 0);
        BOOL currentlyRevealed = isNotes ? self.customerNotesRevealed : self.customerIdRevealed;

        if (currentlyRevealed) {
            // Re-mask — no auth needed.
            if (isNotes) { self.customerNotesRevealed = NO; }
            else         { self.customerIdRevealed = NO; }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }

        // Unmask requires biometric re-auth + audit entry per design.md §8.
        NSString *field = isNotes ? @"customerNotes" : @"sensitiveCustomerId";
        __weak typeof(self) weakSelf = self;
        [CMBiometricAuth evaluatePolicy:CMBiometricPolicyStandard
                                 reason:@"Reveal sensitive information"
                             completion:^(BOOL success, NSError *error) {
            if (!success) {
                [CMHaptics error];
                return;
            }
            if (isNotes) { weakSelf.customerNotesRevealed = YES; }
            else         { weakSelf.customerIdRevealed = YES; }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

            [[CMAuditService shared] recordAction:@"sensitive.unmask_viewed"
                                       targetType:@"Order"
                                         targetId:weakSelf.order.orderId
                                       beforeJSON:nil
                                        afterJSON:@{ @"field": field }
                                           reason:@"User revealed masked field"
                                       completion:nil];
        }];
        return;
    }

    if (indexPath.section == CMOrderDetailSectionActions) {
        NSString *role = [CMTenantContext shared].currentRole;
        CMPermissionMatrix *pm = [CMPermissionMatrix shared];

        // Reconstruct action list matching cellForRow logic (must stay identical)
        NSMutableArray<NSString *> *actions = [NSMutableArray array];
        if ([pm hasPermission:@"orders.assign" forRole:role]) [actions addObject:@"assign"];
        if ([pm hasPermission:@"orders.update_status_own" forRole:role]) [actions addObject:@"update_status"];
        if ([pm hasPermission:@"orders.edit_notes" forRole:role]) [actions addObject:@"edit_notes"];
        if ([pm hasPermission:@"disputes.open" forRole:role]) [actions addObject:@"open_dispute"];
        if ([pm hasPermission:@"attachments.upload_own" forRole:role] ||
            [pm hasPermission:@"attachments.upload_dispute" forRole:role]) [actions addObject:@"capture_photo"];

        if (indexPath.row < (NSInteger)actions.count) {
            NSString *action = actions[indexPath.row];
            if ([action isEqualToString:@"assign"]) {
                [self assignTapped];
            } else if ([action isEqualToString:@"capture_photo"]) {
                [self capturePhotoTapped];
            } else if ([action isEqualToString:@"edit_notes"]) {
                [self editNotesTapped];
            } else if ([action isEqualToString:@"update_status"]) {
                // Courier can only update status on orders assigned to them
                NSString *currentUserId = [CMTenantContext shared].currentUserId;
                if ([role isEqualToString:CMUserRoleCourier] &&
                    (![self.order.assignedCourierId isEqualToString:currentUserId])) {
                    [CMHaptics error];
                    UIAlertController *denied = [UIAlertController alertControllerWithTitle:@"Permission Denied"
                                                                                   message:@"You can only update status on orders assigned to you."
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [denied addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:denied animated:YES completion:nil];
                    return;
                }
                [self updateStatusTapped];
            } else if ([action isEqualToString:@"open_dispute"]) {
                [self openDisputeTapped];
            }
        }
    }
}

- (void)showPermissionDenied {
    [CMHaptics error];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Permission Denied"
                                                                  message:@"You do not have permission to perform this action."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
