//
//  CMAuthProviderTests.m
//  CourierMatch Unit Tests
//
//  Verifies CMAuthProvider protocol constants and CMAuthFactor bitmask values.
//

#import <XCTest/XCTest.h>
#import "CMAuthProvider.h"

@interface CMAuthProviderTests : XCTestCase
@end

@implementation CMAuthProviderTests

#pragma mark - kFeatureRemoteAuthEnabled

- (void)testRemoteAuthIsDisabledInOfflineBuild {
    XCTAssertFalse(kFeatureRemoteAuthEnabled,
                   @"Remote auth must be disabled (offline build — kFeatureRemoteAuthEnabled == NO)");
}

#pragma mark - CMAuthFactor Bitmask Values

- (void)testAuthFactorNoneIsZero {
    XCTAssertEqual((NSUInteger)CMAuthFactorNone, 0u);
}

- (void)testAuthFactorPasswordIsBit0 {
    XCTAssertEqual((NSUInteger)CMAuthFactorPassword, 1u);
}

- (void)testAuthFactorBiometricIsBit1 {
    XCTAssertEqual((NSUInteger)CMAuthFactorBiometric, 2u);
}

- (void)testAuthFactorRemoteIsBit2 {
    XCTAssertEqual((NSUInteger)CMAuthFactorRemote, 4u);
}

- (void)testAuthFactorsBitwiseCombine {
    CMAuthFactor combined = CMAuthFactorPassword | CMAuthFactorBiometric;
    XCTAssertTrue(combined & CMAuthFactorPassword, @"Combined factor should include Password");
    XCTAssertTrue(combined & CMAuthFactorBiometric, @"Combined factor should include Biometric");
    XCTAssertFalse(combined & CMAuthFactorRemote, @"Combined factor should not include Remote");
}

- (void)testAuthFactorNoneDoesNotOverlapOthers {
    XCTAssertFalse(CMAuthFactorNone & CMAuthFactorPassword);
    XCTAssertFalse(CMAuthFactorNone & CMAuthFactorBiometric);
    XCTAssertFalse(CMAuthFactorNone & CMAuthFactorRemote);
}

@end
