//
//  CMBiometricAuth.h
//  CourierMatch
//
//  LocalAuthentication wrapper per design.md §4.2.
//  Biometrics never act as a primary secret — they unlock a Keychain-stored
//  session re-issue token. ALL policies use biometrics-only (no passcode
//  fallback) per the prompt requirement for destructive-action biometric re-auth.
//

#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMBiometricPolicy) {
    CMBiometricPolicyStandard    = 0,   // biometrics-only
    CMBiometricPolicyLogin       = 0,   // alias for standard
    CMBiometricPolicyDestructive = 1,   // biometrics-only (no passcode fallback)
};

typedef void (^CMBiometricCompletion)(BOOL success, NSError * _Nullable error);

@interface CMBiometricAuth : NSObject

/// `YES` iff the device is enrolled and LocalAuthentication can evaluate
/// biometric policy. Call before offering biometric login.
+ (BOOL)isAvailable;

/// Returns the LAPolicy for the given CMBiometricPolicy.
/// All policies map to LAPolicyDeviceOwnerAuthenticationWithBiometrics.
+ (LAPolicy)laPolicyFor:(CMBiometricPolicy)policy;

/// Presents the biometric prompt. `reason` is shown to the user.
/// Completion always fires on the main thread.
+ (void)evaluatePolicy:(CMBiometricPolicy)policy
                reason:(NSString *)reason
            completion:(CMBiometricCompletion)completion;

@end

NS_ASSUME_NONNULL_END
