//
//  CMItineraryFormViewController.m
//  CourierMatch
//

#import "CMItineraryFormViewController.h"
#import "CMItinerary.h"
#import "CMAddress.h"
#import "CMAddressNormalizer.h"
#import "CMItineraryRepository.h"
#import "CMLocationPrefill.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMHaptics.h"
#import "NSManagedObjectContext+CMHelpers.h"
#import "CMSaveWithVersionCheckPolicy+UI.h"

static NSArray<NSString *> *CMVehicleTypeOptions(void) {
    return @[CMVehicleTypeBike, CMVehicleTypeCar, CMVehicleTypeVan, CMVehicleTypeTruck];
}

@interface CMItineraryFormViewController ()
@property (nonatomic, strong, nullable) CMItinerary *itinerary;
@property (nonatomic, assign) BOOL isEditMode;
@property (nonatomic, assign) int64_t baseVersion;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *formStack;

// Origin fields
@property (nonatomic, strong) UITextField *originLine1Field;
@property (nonatomic, strong) UITextField *originCityField;
@property (nonatomic, strong) UITextField *originStateField;
@property (nonatomic, strong) UITextField *originZipField;

// Destination fields
@property (nonatomic, strong) UITextField *destLine1Field;
@property (nonatomic, strong) UITextField *destCityField;
@property (nonatomic, strong) UITextField *destStateField;
@property (nonatomic, strong) UITextField *destZipField;

// Departure window
@property (nonatomic, strong) UIDatePicker *departureStartPicker;
@property (nonatomic, strong) UIDatePicker *departureEndPicker;

// Vehicle
@property (nonatomic, strong) UISegmentedControl *vehicleTypeControl;
@property (nonatomic, strong) UITextField *volumeField;
@property (nonatomic, strong) UITextField *weightField;

// Stops
@property (nonatomic, strong) UIStackView *stopsStack;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, UITextField *> *> *stopFieldGroups;

// Save button
@property (nonatomic, strong) UIButton *saveButton;

// Location prefill
@property (nonatomic, strong) CMLocationPrefill *locationPrefill;
@property (nonatomic, strong) UILabel *approximateLabel;
@end

@implementation CMItineraryFormViewController

- (instancetype)initWithItinerary:(CMItinerary *)itinerary {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _itinerary = itinerary;
        _isEditMode = (itinerary != nil);
        _baseVersion = itinerary ? itinerary.version : 0;
        _stopFieldGroups = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.isEditMode ? @"Edit Itinerary" : @"New Itinerary";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupForm];

    if (self.isEditMode) {
        [self populateFromItinerary];
    }
}

#pragma mark - Form Setup

- (void)setupForm {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    ]];

    _formStack = [[UIStackView alloc] init];
    _formStack.translatesAutoresizingMaskIntoConstraints = NO;
    _formStack.axis = UILayoutConstraintAxisVertical;
    _formStack.spacing = 12;
    [_scrollView addSubview:_formStack];
    [NSLayoutConstraint activateConstraints:@[
        [_formStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor constant:16],
        [_formStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor constant:16],
        [_formStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor constant:-16],
        [_formStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor constant:-16],
        [_formStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    // --- Origin Address ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"Origin Address"]];
    _originLine1Field = [self makeTextField:@"Street Address"];
    _originLine1Field.accessibilityLabel = @"Origin street address";
    [_formStack addArrangedSubview:_originLine1Field];

    _originCityField = [self makeTextField:@"City"];
    _originCityField.accessibilityLabel = @"Origin city";
    [_formStack addArrangedSubview:_originCityField];

    _originStateField = [self makeTextField:@"State (e.g. NY or New York)"];
    _originStateField.autocorrectionType = UITextAutocorrectionTypeNo;
    _originStateField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _originStateField.accessibilityLabel = @"Origin state";
    [_formStack addArrangedSubview:_originStateField];

    _originZipField = [self makeTextField:@"ZIP Code (e.g. 10001)"];
    _originZipField.keyboardType = UIKeyboardTypeNumberPad;
    _originZipField.autocorrectionType = UITextAutocorrectionTypeNo;
    _originZipField.accessibilityLabel = @"Origin ZIP code";
    [_formStack addArrangedSubview:_originZipField];

    // --- Use Current Location button ---
    UIButton *locationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    locationButton.translatesAutoresizingMaskIntoConstraints = NO;
    [locationButton setTitle:@"Use Current Location" forState:UIControlStateNormal];
    locationButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    locationButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    locationButton.accessibilityLabel = @"Use current location to prefill origin address";
    locationButton.accessibilityTraits = UIAccessibilityTraitButton;
    [locationButton addTarget:self action:@selector(useCurrentLocationTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [locationButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [_formStack addArrangedSubview:locationButton];

    // Approximate location label (hidden by default)
    _approximateLabel = [[UILabel alloc] init];
    _approximateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _approximateLabel.text = @"(approximate location)";
    _approximateLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _approximateLabel.adjustsFontForContentSizeCategory = YES;
    _approximateLabel.textColor = [UIColor secondaryLabelColor];
    _approximateLabel.accessibilityLabel = @"Origin address is approximate based on current location";
    _approximateLabel.hidden = YES;
    [_formStack addArrangedSubview:_approximateLabel];

    // --- Destination Address ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"Destination Address"]];
    _destLine1Field = [self makeTextField:@"Street Address"];
    _destLine1Field.accessibilityLabel = @"Destination street address";
    [_formStack addArrangedSubview:_destLine1Field];

    _destCityField = [self makeTextField:@"City"];
    _destCityField.accessibilityLabel = @"Destination city";
    [_formStack addArrangedSubview:_destCityField];

    _destStateField = [self makeTextField:@"State (e.g. CA or California)"];
    _destStateField.autocorrectionType = UITextAutocorrectionTypeNo;
    _destStateField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _destStateField.accessibilityLabel = @"Destination state";
    [_formStack addArrangedSubview:_destStateField];

    _destZipField = [self makeTextField:@"ZIP Code (e.g. 90001)"];
    _destZipField.keyboardType = UIKeyboardTypeNumberPad;
    _destZipField.autocorrectionType = UITextAutocorrectionTypeNo;
    _destZipField.accessibilityLabel = @"Destination ZIP code";
    [_formStack addArrangedSubview:_destZipField];

    // --- Departure Window ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"Departure Window Start"]];
    _departureStartPicker = [[UIDatePicker alloc] init];
    _departureStartPicker.translatesAutoresizingMaskIntoConstraints = NO;
    _departureStartPicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 14.0, *)) {
        _departureStartPicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    _departureStartPicker.accessibilityLabel = @"Departure window start";
    [_formStack addArrangedSubview:_departureStartPicker];

    [_formStack addArrangedSubview:[self makeSectionLabel:@"Departure Window End"]];
    _departureEndPicker = [[UIDatePicker alloc] init];
    _departureEndPicker.translatesAutoresizingMaskIntoConstraints = NO;
    _departureEndPicker.datePickerMode = UIDatePickerModeDateAndTime;
    if (@available(iOS 14.0, *)) {
        _departureEndPicker.preferredDatePickerStyle = UIDatePickerStyleCompact;
    }
    _departureEndPicker.accessibilityLabel = @"Departure window end";
    [_formStack addArrangedSubview:_departureEndPicker];

    // --- Vehicle Type ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"Vehicle Type"]];
    NSArray<NSString *> *vehicleOptions = CMVehicleTypeOptions();
    NSMutableArray<NSString *> *vehicleTitles = [NSMutableArray array];
    for (NSString *v in vehicleOptions) {
        [vehicleTitles addObject:v.capitalizedString];
    }
    _vehicleTypeControl = [[UISegmentedControl alloc] initWithItems:vehicleTitles];
    _vehicleTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    _vehicleTypeControl.selectedSegmentIndex = 0;
    _vehicleTypeControl.accessibilityLabel = @"Vehicle type";
    [_formStack addArrangedSubview:_vehicleTypeControl];

    // --- Capacity ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"Capacity"]];
    _volumeField = [self makeTextField:@"Volume (Liters)"];
    _volumeField.keyboardType = UIKeyboardTypeDecimalPad;
    _volumeField.accessibilityLabel = @"Capacity volume in liters";
    [_formStack addArrangedSubview:_volumeField];

    _weightField = [self makeTextField:@"Weight (kg)"];
    _weightField.keyboardType = UIKeyboardTypeDecimalPad;
    _weightField.accessibilityLabel = @"Capacity weight in kilograms";
    [_formStack addArrangedSubview:_weightField];

    // --- On-the-Way Stops ---
    [_formStack addArrangedSubview:[self makeSectionLabel:@"On-the-Way Stops"]];

    _stopsStack = [[UIStackView alloc] init];
    _stopsStack.translatesAutoresizingMaskIntoConstraints = NO;
    _stopsStack.axis = UILayoutConstraintAxisVertical;
    _stopsStack.spacing = 8;
    [_formStack addArrangedSubview:_stopsStack];

    UIButton *addStopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addStopButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addStopButton setTitle:@"Add Stop" forState:UIControlStateNormal];
    addStopButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    addStopButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    addStopButton.accessibilityLabel = @"Add on-the-way stop";
    addStopButton.accessibilityTraits = UIAccessibilityTraitButton;
    [addStopButton addTarget:self action:@selector(addStopTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [addStopButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [_formStack addArrangedSubview:addStopButton];

    // --- Save Button ---
    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:@"Save" forState:UIControlStateNormal];
    _saveButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    _saveButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    _saveButton.backgroundColor = [UIColor systemBlueColor];
    [_saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _saveButton.layer.cornerRadius = 10;
    _saveButton.accessibilityLabel = @"Save itinerary";
    _saveButton.accessibilityTraits = UIAccessibilityTraitButton;
    [_saveButton addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [_saveButton.heightAnchor constraintEqualToConstant:50],
    ]];
    [_formStack addArrangedSubview:_saveButton];
}

#pragma mark - Pre-populate Edit Mode

- (void)populateFromItinerary {
    CMItinerary *it = self.itinerary;

    // Origin
    if (it.originAddress) {
        self.originLine1Field.text = it.originAddress.line1;
        self.originCityField.text = it.originAddress.city;
        self.originStateField.text = it.originAddress.stateAbbr;
        self.originZipField.text = it.originAddress.zip;
    }

    // Destination
    if (it.destinationAddress) {
        self.destLine1Field.text = it.destinationAddress.line1;
        self.destCityField.text = it.destinationAddress.city;
        self.destStateField.text = it.destinationAddress.stateAbbr;
        self.destZipField.text = it.destinationAddress.zip;
    }

    // Departure window
    if (it.departureWindowStart) {
        self.departureStartPicker.date = it.departureWindowStart;
    }
    if (it.departureWindowEnd) {
        self.departureEndPicker.date = it.departureWindowEnd;
    }

    // Vehicle type
    NSArray<NSString *> *vehicleOptions = CMVehicleTypeOptions();
    NSUInteger idx = [vehicleOptions indexOfObject:it.vehicleType];
    if (idx != NSNotFound) {
        self.vehicleTypeControl.selectedSegmentIndex = (NSInteger)idx;
    }

    // Capacity
    self.volumeField.text = [NSString stringWithFormat:@"%.1f", it.vehicleCapacityVolumeL];
    self.weightField.text = [NSString stringWithFormat:@"%.1f", it.vehicleCapacityWeightKg];

    // Stops
    for (CMAddress *stop in it.onTheWayStops) {
        [self addStopFieldsWithAddress:stop];
    }
}

#pragma mark - Helpers

- (UILabel *)makeSectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UITextField *)makeTextField:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    field.adjustsFontForContentSizeCategory = YES;
    field.placeholder = placeholder;
    field.backgroundColor = [UIColor secondarySystemBackgroundColor];
    field.textColor = [UIColor labelColor];
    [NSLayoutConstraint activateConstraints:@[
        [field.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    return field;
}

#pragma mark - Stops Management

- (void)addStopTapped {
    [self addStopFieldsWithAddress:nil];
}

- (void)addStopFieldsWithAddress:(CMAddress *)address {
    NSInteger stopIndex = (NSInteger)self.stopFieldGroups.count + 1;

    UIStackView *stopGroup = [[UIStackView alloc] init];
    stopGroup.translatesAutoresizingMaskIntoConstraints = NO;
    stopGroup.axis = UILayoutConstraintAxisVertical;
    stopGroup.spacing = 6;
    stopGroup.tag = 9000 + stopIndex;

    UILabel *stopLabel = [self makeSectionLabel:[NSString stringWithFormat:@"Stop %ld", (long)stopIndex]];
    [stopGroup addArrangedSubview:stopLabel];

    UITextField *line1 = [self makeTextField:@"Street Address"];
    line1.accessibilityLabel = [NSString stringWithFormat:@"Stop %ld street address", (long)stopIndex];
    line1.text = address.line1;
    [stopGroup addArrangedSubview:line1];

    UITextField *city = [self makeTextField:@"City"];
    city.accessibilityLabel = [NSString stringWithFormat:@"Stop %ld city", (long)stopIndex];
    city.text = address.city;
    [stopGroup addArrangedSubview:city];

    UITextField *state = [self makeTextField:@"State"];
    state.accessibilityLabel = [NSString stringWithFormat:@"Stop %ld state", (long)stopIndex];
    state.text = address.stateAbbr;
    [stopGroup addArrangedSubview:state];

    UITextField *zip = [self makeTextField:@"ZIP Code"];
    zip.keyboardType = UIKeyboardTypeNumberPad;
    zip.accessibilityLabel = [NSString stringWithFormat:@"Stop %ld ZIP code", (long)stopIndex];
    zip.text = address.zip;
    [stopGroup addArrangedSubview:zip];

    UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [removeButton setTitle:@"Remove Stop" forState:UIControlStateNormal];
    removeButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    removeButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [removeButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    removeButton.accessibilityLabel = [NSString stringWithFormat:@"Remove stop %ld", (long)stopIndex];
    removeButton.accessibilityTraits = UIAccessibilityTraitButton;
    removeButton.tag = (NSInteger)self.stopFieldGroups.count;
    [removeButton addTarget:self action:@selector(removeStopTapped:) forControlEvents:UIControlEventTouchUpInside];
    [NSLayoutConstraint activateConstraints:@[
        [removeButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [stopGroup addArrangedSubview:removeButton];

    [self.stopsStack addArrangedSubview:stopGroup];

    NSDictionary *fields = @{
        @"line1": line1,
        @"city": city,
        @"state": state,
        @"zip": zip,
    };
    [self.stopFieldGroups addObject:fields];
}

- (void)removeStopTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.stopFieldGroups.count) return;

    UIView *stopGroup = self.stopsStack.arrangedSubviews[idx];
    [self.stopsStack removeArrangedSubview:stopGroup];
    [stopGroup removeFromSuperview];
    [self.stopFieldGroups removeObjectAtIndex:(NSUInteger)idx];

    // Re-tag remaining remove buttons
    for (NSUInteger i = 0; i < self.stopFieldGroups.count; i++) {
        UIStackView *group = (UIStackView *)self.stopsStack.arrangedSubviews[i];
        for (UIView *subview in group.arrangedSubviews) {
            if ([subview isKindOfClass:[UIButton class]]) {
                subview.tag = (NSInteger)i;
            }
        }
    }
}

#pragma mark - Location Prefill

- (void)useCurrentLocationTapped {
    if (!self.locationPrefill) {
        self.locationPrefill = [[CMLocationPrefill alloc] init];
    }

    __weak typeof(self) weakSelf = self;
    [self.locationPrefill requestPrefillWithCompletion:^(NSString *city, NSString *state, NSString *zip, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            [CMHaptics warning];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Location Unavailable"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf presentViewController:alert animated:YES completion:nil];
            return;
        }

        // Prefill city, state, ZIP only. Leave line1 blank (Q14).
        strongSelf.originCityField.text = city;
        strongSelf.originStateField.text = state;
        strongSelf.originZipField.text = zip;
        strongSelf.originLine1Field.text = @"";
        strongSelf.approximateLabel.hidden = NO;

        [CMHaptics success];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                        @"Origin address prefilled with approximate location");
    }];
}

#pragma mark - Save

- (void)saveTapped {
    [self.view endEditing:YES];

    // Validate origin address
    CMAddressNormalizer *normalizer = [CMAddressNormalizer shared];
    NSString *originState = self.originStateField.text;
    NSString *originZip   = self.originZipField.text;

    // Give specific feedback on what's wrong
    if (![normalizer stateAbbrFromInput:originState]) {
        [self showValidationError:@"Origin state is not recognized. Use a 2-letter abbreviation (e.g. NY, CA) or full name (e.g. New York)."];
        return;
    }
    if (![normalizer isValidZip:originZip]) {
        [self showValidationError:@"Origin ZIP code must be 5 digits (e.g. 10001) or 5+4 format (e.g. 10001-1234)."];
        return;
    }

    CMNormalizedAddress *normalizedOrigin = [normalizer normalizeLine1:self.originLine1Field.text
                                                                 line2:nil
                                                                  city:self.originCityField.text
                                                                 state:originState
                                                                   zip:originZip];
    if (!normalizedOrigin) {
        [self showValidationError:@"Origin address is invalid. Check all fields."];
        return;
    }

    // Validate destination address
    NSString *destState = self.destStateField.text;
    NSString *destZip   = self.destZipField.text;

    if (![normalizer stateAbbrFromInput:destState]) {
        [self showValidationError:@"Destination state is not recognized. Use a 2-letter abbreviation (e.g. CA, TX) or full name."];
        return;
    }
    if (![normalizer isValidZip:destZip]) {
        [self showValidationError:@"Destination ZIP code must be 5 digits (e.g. 90001) or 5+4 format."];
        return;
    }

    CMNormalizedAddress *normalizedDest = [normalizer normalizeLine1:self.destLine1Field.text
                                                               line2:nil
                                                                city:self.destCityField.text
                                                               state:destState
                                                                 zip:destZip];
    if (!normalizedDest) {
        [self showValidationError:@"Destination address is invalid. Check all fields."];
        return;
    }

    // Validate departure window
    NSDate *startDate = self.departureStartPicker.date;
    NSDate *endDate = self.departureEndPicker.date;
    if ([endDate compare:startDate] != NSOrderedDescending) {
        [self showValidationError:@"Departure window end must be after start."];
        return;
    }

    // Validate capacity
    double volume = self.volumeField.text.doubleValue;
    double weight = self.weightField.text.doubleValue;
    if (volume <= 0) {
        [self showValidationError:@"Volume must be greater than zero."];
        return;
    }
    if (weight <= 0) {
        [self showValidationError:@"Weight must be greater than zero."];
        return;
    }

    // Validate stops
    NSMutableArray<CMAddress *> *stops = [NSMutableArray array];
    for (NSDictionary<NSString *, UITextField *> *fields in self.stopFieldGroups) {
        NSString *sLine1 = fields[@"line1"].text;
        NSString *sCity = fields[@"city"].text;
        NSString *sState = fields[@"state"].text;
        NSString *sZip = fields[@"zip"].text;

        if (sLine1.length == 0 && sCity.length == 0) {
            continue; // Skip empty stops
        }

        CMNormalizedAddress *normStop = [normalizer normalizeLine1:sLine1
                                                             line2:nil
                                                              city:sCity
                                                             state:sState
                                                               zip:sZip];
        if (!normStop) {
            [self showValidationError:@"One or more stop addresses are invalid. Check state and ZIP."];
            return;
        }

        CMAddress *stopAddr = [CMAddress new];
        stopAddr.line1 = normStop.line1;
        stopAddr.city = normStop.city;
        stopAddr.stateAbbr = normStop.stateAbbr;
        stopAddr.zip = normStop.zip;
        stopAddr.normalizedKey = normStop.normalizedKey;
        [stops addObject:stopAddr];
    }

    // Vehicle type
    NSArray<NSString *> *vehicleOptions = CMVehicleTypeOptions();
    NSString *vehicleType = vehicleOptions[(NSUInteger)self.vehicleTypeControl.selectedSegmentIndex];

    // Build address objects
    CMAddress *originAddr = [CMAddress new];
    originAddr.line1 = normalizedOrigin.line1;
    originAddr.city = normalizedOrigin.city;
    originAddr.stateAbbr = normalizedOrigin.stateAbbr;
    originAddr.zip = normalizedOrigin.zip;
    originAddr.normalizedKey = normalizedOrigin.normalizedKey;

    CMAddress *destAddr = [CMAddress new];
    destAddr.line1 = normalizedDest.line1;
    destAddr.city = normalizedDest.city;
    destAddr.stateAbbr = normalizedDest.stateAbbr;
    destAddr.zip = normalizedDest.zip;
    destAddr.normalizedKey = normalizedDest.normalizedKey;

    // Persist
    if (self.isEditMode) {
        [self updateItineraryWithOrigin:originAddr
                            destination:destAddr
                                  start:startDate
                                    end:endDate
                            vehicleType:vehicleType
                                 volume:volume
                                 weight:weight
                                  stops:stops];
    } else {
        [self createItineraryWithOrigin:originAddr
                            destination:destAddr
                                  start:startDate
                                    end:endDate
                            vehicleType:vehicleType
                                 volume:volume
                                 weight:weight
                                  stops:stops];
    }
}

- (void)updateItineraryWithOrigin:(CMAddress *)origin
                      destination:(CMAddress *)dest
                            start:(NSDate *)start
                              end:(NSDate *)end
                      vehicleType:(NSString *)vehicleType
                           volume:(double)volume
                           weight:(double)weight
                            stops:(NSArray<CMAddress *> *)stops {
    NSDictionary *changes = @{
        @"originAddress":           origin,
        @"destinationAddress":      dest,
        @"departureWindowStart":    start,
        @"departureWindowEnd":      end,
        @"vehicleType":             vehicleType,
        @"vehicleCapacityVolumeL":  @(volume),
        @"vehicleCapacityWeightKg": @(weight),
        @"onTheWayStops":           stops,
        @"updatedAt":               [NSDate date],
        @"updatedBy":               [CMTenantContext shared].currentUserId ?: @""
    };

    [CMSaveWithVersionCheckPolicy saveChanges:changes
                                     toObject:self.itinerary
                                  baseVersion:self.baseVersion
                          fromViewController:self
                                   completion:^(BOOL saved) {
        if (saved) {
            self.baseVersion = self.itinerary.version;
            [CMHaptics success];
            [self.navigationController popViewControllerAnimated:YES];
        } else {
            [CMHaptics error];
        }
    }];
}

- (void)createItineraryWithOrigin:(CMAddress *)origin
                      destination:(CMAddress *)dest
                            start:(NSDate *)start
                              end:(NSDate *)end
                      vehicleType:(NSString *)vehicleType
                           volume:(double)volume
                           weight:(double)weight
                            stops:(NSArray<CMAddress *> *)stops {
    // Save on the viewContext so the list VC sees the new itinerary immediately
    // when it calls viewWillAppear → loadData after we pop.
    NSManagedObjectContext *ctx = [CMCoreDataStack shared].viewContext;
    CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:ctx];
    CMItinerary *it = [repo insertItinerary];
    it.originAddress = origin;
    it.destinationAddress = dest;
    it.departureWindowStart = start;
    it.departureWindowEnd = end;
    it.vehicleType = vehicleType;
    it.vehicleCapacityVolumeL = volume;
    it.vehicleCapacityWeightKg = weight;
    it.onTheWayStops = stops;
    it.courierId = [CMTenantContext shared].currentUserId ?: @"";
    it.status = CMItineraryStatusActive;

    NSError *saveErr = nil;
    BOOL saved = [ctx cm_saveWithError:&saveErr];
    if (saved) {
        [CMHaptics success];
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [CMHaptics error];
        [self showValidationError:saveErr.localizedDescription ?: @"Failed to save."];
    }
}

- (void)showValidationError:(NSString *)message {
    [CMHaptics warning];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Validation Error"
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
