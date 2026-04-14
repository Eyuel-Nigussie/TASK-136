//
//  CMBiometricEnrollment.m
//  CourierMatch
//

#import "CMBiometricEnrollment.h"
#import "CMBiometricAuth.h"
#import "CMUserAccount.h"
#import "CMKeychain.h"
#import "CMKeychainKeys.h"
#import "CMCoreDataStack.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"
#import <Security/Security.h>

static NSString *const kTagEnrollment = @"biometric.enrollment";

@implementation CMBiometricEnrollment

+ (void)enrollBiometricsForUser:(CMUserAccount *)user
                     completion:(CMBiometricEnrollmentCompletion)completion {
    if (![CMBiometricAuth isAvailable]) {
        NSError *err = [CMError errorWithCode:CMErrorCodeBiometricUnavailable
                                       message:@"Biometrics are not available on this device"];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, err);
            });
        }
        return;
    }

    NSString *userId = user.userId;
    NSManagedObjectID *objectID = user.objectID;

    [CMBiometricAuth evaluatePolicy:CMBiometricPolicyStandard
                             reason:@"Enable biometric sign-in for CourierMatch"
                         completion:^(BOOL success, NSError * _Nullable laError) {
        if (!success) {
            CMLogWarn(kTagEnrollment, @"biometric evaluation failed for user");
            if (completion) {
                completion(NO, laError);
            }
            return;
        }

        // Generate 32-byte random token.
        NSMutableData *tokenData = [NSMutableData dataWithLength:32];
        int rc = SecRandomCopyBytes(kSecRandomDefault, 32, tokenData.mutableBytes);
        if (rc != errSecSuccess) {
            NSError *err = [CMError errorWithCode:CMErrorCodeCryptoOperationFailed
                                           message:@"Failed to generate biometric session token"];
            CMLogError(kTagEnrollment, @"SecRandomCopyBytes failed");
            if (completion) {
                completion(NO, err);
            }
            return;
        }

        // Write token to Keychain.
        NSString *keychainKey = [CMKeychainKey_SessionTokenPrefix stringByAppendingString:userId];
        NSError *keychainError = nil;
        BOOL wrote = [CMKeychain setData:tokenData forKey:keychainKey error:&keychainError];
        if (!wrote) {
            CMLogError(kTagEnrollment, @"keychain write failed: %@", keychainError);
            if (completion) {
                completion(NO, keychainError);
            }
            return;
        }

        // Update user record on a background context.
        [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
            CMUserAccount *bgUser = (CMUserAccount *)[ctx objectWithID:objectID];
            bgUser.biometricEnabled = YES;
            bgUser.biometricRefId = keychainKey;
            bgUser.updatedAt = [NSDate date];

            NSError *saveErr = nil;
            if (![ctx cm_saveWithError:&saveErr]) {
                CMLogError(kTagEnrollment, @"Core Data save failed: %@", saveErr);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(NO, saveErr);
                    }
                });
                return;
            }

            CMLogInfo(kTagEnrollment, @"biometric enrollment succeeded for user");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(YES, nil);
                }
            });
        }];
    }];
}

@end
