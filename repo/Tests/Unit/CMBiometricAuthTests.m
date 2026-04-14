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

@end
