//
//  CMLocationPrefill.m
//  CourierMatch
//

#import "CMLocationPrefill.h"
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface CMLocationPrefill () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, copy, nullable) void (^prefillCompletion)(NSString *, NSString *, NSString *, NSError *);
@property (nonatomic, assign) BOOL didReceiveFix;
@end

@implementation CMLocationPrefill

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyReduced;
        _geocoder = [[CLGeocoder alloc] init];
        _didReceiveFix = NO;

        // Listen for background entry to stop updates (Q14).
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_locationManager stopUpdatingLocation];
}

- (void)requestPrefillWithCompletion:(void (^)(NSString * _Nullable,
                                               NSString * _Nullable,
                                               NSString * _Nullable,
                                               NSError * _Nullable))completion {
    self.prefillCompletion = completion;
    self.didReceiveFix = NO;

    CLAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = self.locationManager.authorizationStatus;
    } else {
        status = [CLLocationManager authorizationStatus];
    }

    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        // Authorization delegate will trigger location updates after user responds.
        return;
    }

    if (status == kCLAuthorizationStatusDenied ||
        status == kCLAuthorizationStatusRestricted) {
        [self completeWithError:[NSError errorWithDomain:@"CMLocationPrefill"
                                                    code:1
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                               @"Location access denied. Enable in Settings."}]];
        return;
    }

    [self.locationManager startUpdatingLocation];
}

- (void)cancel {
    [self.locationManager stopUpdatingLocation];
    if (self.geocoder.isGeocoding) {
        [self.geocoder cancelGeocode];
    }
    self.prefillCompletion = nil;
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (@available(iOS 14.0, *)) {
        CLAuthorizationStatus status = manager.authorizationStatus;
        if (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
            status == kCLAuthorizationStatusAuthorizedAlways) {
            [self.locationManager startUpdatingLocation];
        } else if (status == kCLAuthorizationStatusDenied ||
                   status == kCLAuthorizationStatusRestricted) {
            [self completeWithError:[NSError errorWithDomain:@"CMLocationPrefill"
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey:
                                                                   @"Location access denied."}]];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (self.didReceiveFix) return;
    self.didReceiveFix = YES;

    // Stop immediately after one fix.
    [self.locationManager stopUpdatingLocation];

    CLLocation *location = locations.lastObject;
    if (!location) {
        [self completeWithError:[NSError errorWithDomain:@"CMLocationPrefill"
                                                    code:2
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                               @"No location available."}]];
        return;
    }

    // Reverse geocode for city/state/zip.
    [self.geocoder reverseGeocodeLocation:location
                        completionHandler:^(NSArray<CLPlacemark *> *placemarks,
                                            NSError *error) {
        if (error || placemarks.count == 0) {
            // Fallback: return empty approximate fields.
            [self completeWithCity:@"" state:@"" zip:@""];
            return;
        }

        CLPlacemark *pm = placemarks.firstObject;
        NSString *city  = pm.locality ?: @"";
        NSString *state = pm.administrativeArea ?: @"";
        NSString *zip   = pm.postalCode ?: @"";

        [self completeWithCity:city state:state zip:zip];
    }];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    [self.locationManager stopUpdatingLocation];
    [self completeWithError:error];
}

#pragma mark - Background

- (void)appDidEnterBackground:(NSNotification *)note {
    [self.locationManager stopUpdatingLocation];
}

#pragma mark - Completion helpers

- (void)completeWithCity:(NSString *)city state:(NSString *)state zip:(NSString *)zip {
    void (^block)(NSString *, NSString *, NSString *, NSError *) = self.prefillCompletion;
    self.prefillCompletion = nil;
    if (!block) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        block(city, state, zip, nil);
    });
}

- (void)completeWithError:(NSError *)error {
    void (^block)(NSString *, NSString *, NSString *, NSError *) = self.prefillCompletion;
    self.prefillCompletion = nil;
    if (!block) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        block(nil, nil, nil, error);
    });
}

@end
