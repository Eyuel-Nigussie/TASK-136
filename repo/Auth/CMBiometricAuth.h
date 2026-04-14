//
//  CMBiometricAuth.h
//  CourierMatch
//
//  LocalAuthentication wrapper per design.md §4.2.
//  Biometrics never act as a primary secret — they unlock a Keychain-stored
//  session re-issue token. Destructive actions use the stricter owner-auth
//  policy (allows passcode fallback) for re-auth.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMBiometricPolicy) {
    CMBiometricPolicyStandard    = 0,   // LAPolicyDeviceOwnerAuthenticationWithBiometrics
    CMBiometricPolicyDestructive = 1,   // LAPolicyDeviceOwnerAuthentication
};

typedef void (^CMBiometricCompletion)(BOOL success, NSError * _Nullable error);

@interface CMBiometricAuth : NSObject

/// `YES` iff the device is enrolled and LocalAuthentication can evaluate
/// `CMBiometricPolicyStandard`. Call before offering biometric login.
+ (BOOL)isAvailable;

/// Presents the biometric prompt. `reason` is shown to the user.
/// Completion always fires on the main thread.
+ (void)evaluatePolicy:(CMBiometricPolicy)policy
                reason:(NSString *)reason
            completion:(CMBiometricCompletion)completion;

@end

NS_ASSUME_NONNULL_END
