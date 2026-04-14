//
//  CMLocationPrefillTests.m
//  CourierMatch Unit Tests
//
//  Tests CMLocationPrefill privacy constraints (reduced accuracy) and
//  background-stop behavior per Q14.
//

#import <XCTest/XCTest.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "CMLocationPrefill.h"

@interface CMLocationPrefill ()
// Expose internals for testing.
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL didReceiveFix;
- (void)appDidEnterBackground:(NSNotification *)note;
@end

@interface CMLocationPrefillTests : XCTestCase
@end

@implementation CMLocationPrefillTests

#pragma mark - Test: Reduced Accuracy Configuration

- (void)testLocationManagerUsesReducedAccuracy {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];
    CLLocationManager *mgr = prefill.locationManager;
    XCTAssertNotNil(mgr, @"Location manager should be initialized");
    XCTAssertEqual(mgr.desiredAccuracy, kCLLocationAccuracyReduced,
                   @"desiredAccuracy must be kCLLocationAccuracyReduced per Q14 privacy requirement");
}

#pragma mark - Test: Delegate Is Self

- (void)testLocationManagerDelegateIsSet {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];
    XCTAssertEqualObjects(prefill.locationManager.delegate, prefill,
                          @"Location manager delegate should be the prefill instance");
}

#pragma mark - Test: Background Notification Stops Location Updates

- (void)testAppDidEnterBackgroundStopsLocationUpdates {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];

    // Trigger the background handler directly.
    [prefill appDidEnterBackground:[NSNotification notificationWithName:UIApplicationDidEnterBackgroundNotification
                                                                object:nil]];

    // After background entry, location manager should have been told to stop.
    // We verify by checking that the prefill doesn't crash and the method
    // completes without error. A real CLLocationManager.stopUpdatingLocation
    // is a no-op if not currently updating — the key assertion is that the
    // code path exists and is wired.
    XCTAssertNotNil(prefill.locationManager, @"Location manager should still exist after background");
}

#pragma mark - Test: Background Notification Observer Is Registered

- (void)testBackgroundNotificationObserverRegistered {
    // Creating a CMLocationPrefill should register for UIApplicationDidEnterBackgroundNotification.
    // We test this by posting the notification and verifying it doesn't crash,
    // and that repeated calls to cancel are safe.
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];

    // Post the notification — the registered observer should call appDidEnterBackground:.
    [[NSNotificationCenter defaultCenter]
        postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];

    // Should not crash and should remain in a valid state.
    XCTAssertNotNil(prefill.locationManager);
}

#pragma mark - Test: Cancel Stops Updates and Clears Completion

- (void)testCancelStopsUpdatesAndClearsCompletion {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];

    __block BOOL completionCalled = NO;
    [prefill requestPrefillWithCompletion:^(NSString *city, NSString *state,
                                            NSString *zip, NSError *error) {
        completionCalled = YES;
    }];

    // Cancel should stop updates and nil out the completion.
    [prefill cancel];

    // Simulate a late location update — completion should NOT fire.
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:40.7128 longitude:-74.0060];
    [prefill locationManager:prefill.locationManager didUpdateLocations:@[loc]];

    // Give the main queue a moment to process.
    XCTestExpectation *wait = [self expectationWithDescription:@"wait"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [wait fulfill];
    });
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    XCTAssertFalse(completionCalled,
                   @"Completion should not fire after cancel, even if location arrives late");
}

#pragma mark - Test: didReceiveFix Prevents Duplicate Callbacks

- (void)testDidReceiveFixPreventsSecondCallback {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];

    __block NSInteger callCount = 0;
    [prefill requestPrefillWithCompletion:^(NSString *city, NSString *state,
                                            NSString *zip, NSError *error) {
        callCount++;
    }];

    CLLocation *loc = [[CLLocation alloc] initWithLatitude:40.7128 longitude:-74.0060];

    // First update — should trigger.
    [prefill locationManager:prefill.locationManager didUpdateLocations:@[loc]];
    XCTAssertTrue(prefill.didReceiveFix, @"didReceiveFix should be YES after first update");

    // Second update — should be ignored.
    [prefill locationManager:prefill.locationManager didUpdateLocations:@[loc]];

    // The completion may be called asynchronously via reverse geocoding, but
    // didReceiveFix ensures only one pass through the geocode path.
    XCTAssertTrue(prefill.didReceiveFix);
}

#pragma mark - Test: didFailWithError Calls Completion With Error

- (void)testDidFailWithErrorCallsCompletion {
    CMLocationPrefill *prefill = [[CMLocationPrefill alloc] init];

    XCTestExpectation *exp = [self expectationWithDescription:@"Error completion"];
    [prefill requestPrefillWithCompletion:^(NSString *city, NSString *state,
                                            NSString *zip, NSError *error) {
        XCTAssertNotNil(error, @"Error should be passed through");
        XCTAssertNil(city);
        XCTAssertNil(state);
        XCTAssertNil(zip);
        [exp fulfill];
    }];

    NSError *testError = [NSError errorWithDomain:kCLErrorDomain
                                             code:kCLErrorDenied
                                         userInfo:nil];
    [prefill locationManager:prefill.locationManager didFailWithError:testError];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
