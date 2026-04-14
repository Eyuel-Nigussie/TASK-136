//
//  CMAuthProvider.h
//  CourierMatch
//
//  Extensible authentication provider protocol per design.md §4.5.
//  Only `LocalPasswordAuthProvider` and `BiometricAuthProvider` are registered
//  in this offline build. Remote providers stay behind
//      kFeatureRemoteAuthEnabled = NO
//  and are not registered with the AuthService.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, CMAuthFactor) {
    CMAuthFactorNone        = 0,
    CMAuthFactorPassword    = 1 << 0,
    CMAuthFactorBiometric   = 1 << 1,
    CMAuthFactorRemote      = 1 << 2,  // reserved; never set in offline build
};

extern BOOL const kFeatureRemoteAuthEnabled;

@class CMUserAccount;

typedef void (^CMAuthCompletion)(CMUserAccount * _Nullable user, NSError * _Nullable error);

@protocol CMAuthProvider <NSObject>

/// Unique identifier, e.g. `@"local.password"`, `@"local.biometric"`.
- (NSString *)identifier;

/// Bitmask of factors this provider offers.
- (CMAuthFactor)supportedFactors;

/// NO → provider will refuse to run. `CMAuthService` filters disabled providers.
- (BOOL)isEnabled;

/// Credentials dictionary shape is provider-specific. Implementations must
/// validate input and call `completion` on the main queue.
- (void)authenticateWithCredentials:(NSDictionary<NSString *, id> *)credentials
                         completion:(CMAuthCompletion)completion;

@end

NS_ASSUME_NONNULL_END
