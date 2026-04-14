//
//  CMBiometricEnrollment.h
//  CourierMatch
//
//  Biometric enrollment flow: generates a per-user session token, writes it
//  to the Keychain, and updates the user's biometric flags.
//  See design.md §4.2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMUserAccount;

typedef void (^CMBiometricEnrollmentCompletion)(BOOL success, NSError * _Nullable error);

@interface CMBiometricEnrollment : NSObject

/// Evaluates biometric policy, generates a 32-byte random session token,
/// writes it to the Keychain at `CMKeychainKey_SessionTokenPrefix + userId`,
/// and updates the user's `biometricEnabled` and `biometricRefId`.
/// Completion fires on the main thread.
+ (void)enrollBiometricsForUser:(CMUserAccount *)user
                     completion:(CMBiometricEnrollmentCompletion)completion;

@end

NS_ASSUME_NONNULL_END
