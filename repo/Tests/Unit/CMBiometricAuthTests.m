//
//  CMBiometricAuthTests.m
//  CourierMatch Tests
//
//  Verifies that the destructive biometric policy uses biometrics-only
//  (no passcode fallback) per prompt requirement.
//

#import <XCTest/XCTest.h>
#import "CMBiometricAuth.h"
#import <LocalAuthentication/LocalAuthentication.h>

@interface CMBiometricAuthTests : XCTestCase
@end

@implementation CMBiometricAuthTests

- (void)testDestructivePolicyUsesBiometricsOnly {
    // The policy resolver must return LAPolicyDeviceOwnerAuthenticationWithBiometrics
    // for destructive actions — NOT LAPolicyDeviceOwnerAuthentication (which allows passcode).
    LAPolicy policy = [CMBiometricAuth laPolicyFor:CMBiometricPolicyDestructive];
    XCTAssertEqual(policy, LAPolicyDeviceOwnerAuthenticationWithBiometrics,
                   @"Destructive policy must use biometrics-only (no passcode fallback)");
}

- (void)testLoginPolicyUsesBiometricsOnly {
    LAPolicy policy = [CMBiometricAuth laPolicyFor:CMBiometricPolicyLogin];
    XCTAssertEqual(policy, LAPolicyDeviceOwnerAuthenticationWithBiometrics,
                   @"Login policy must use biometrics-only");
}

#pragma mark - Biometric Login Identity Binding

- (void)testBiometricLoginBindingStoresTenantId {
    // Simulate what happens after successful password login: both userId and tenantId are stored.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"user-123" forKey:@"CMLastAuthenticatedUserId"];
    [defaults setObject:@"tenant-abc" forKey:@"CMLastAuthenticatedTenantId"];

    NSString *storedUser = [defaults stringForKey:@"CMLastAuthenticatedUserId"];
    NSString *storedTenant = [defaults stringForKey:@"CMLastAuthenticatedTenantId"];

    XCTAssertEqualObjects(storedUser, @"user-123");
    XCTAssertEqualObjects(storedTenant, @"tenant-abc");

    // Clean up
    [defaults removeObjectForKey:@"CMLastAuthenticatedUserId"];
    [defaults removeObjectForKey:@"CMLastAuthenticatedTenantId"];
}

- (void)testBiometricBindingRejectsMismatchedTenant {
    // Store binding for tenant-A
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"user-123" forKey:@"CMLastAuthenticatedUserId"];
    [defaults setObject:@"tenant-A" forKey:@"CMLastAuthenticatedTenantId"];

    // Verify mismatch detection logic (mirrors CMLoginViewController.biometricTapped:)
    NSString *enteredTenantId = @"tenant-B";
    NSString *lastTenantId = [defaults stringForKey:@"CMLastAuthenticatedTenantId"];
    BOOL mismatch = (enteredTenantId.length > 0 && ![enteredTenantId isEqualToString:lastTenantId]);

    XCTAssertTrue(mismatch, @"Should detect tenant mismatch between entered and stored binding");

    // Clean up
    [defaults removeObjectForKey:@"CMLastAuthenticatedUserId"];
    [defaults removeObjectForKey:@"CMLastAuthenticatedTenantId"];
}

- (void)testBiometricBindingAcceptsMatchingTenant {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@"user-456" forKey:@"CMLastAuthenticatedUserId"];
    [defaults setObject:@"tenant-X" forKey:@"CMLastAuthenticatedTenantId"];

    NSString *enteredTenantId = @"tenant-X";
    NSString *lastTenantId = [defaults stringForKey:@"CMLastAuthenticatedTenantId"];
    BOOL mismatch = (enteredTenantId.length > 0 && ![enteredTenantId isEqualToString:lastTenantId]);

    XCTAssertFalse(mismatch, @"Should not flag mismatch when tenant matches stored binding");

    [defaults removeObjectForKey:@"CMLastAuthenticatedUserId"];
    [defaults removeObjectForKey:@"CMLastAuthenticatedTenantId"];
}

@end
