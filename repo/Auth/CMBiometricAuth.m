//
//  CMBiometricAuth.m
//  CourierMatch
//

#import "CMBiometricAuth.h"
#import "CMError.h"
#import <LocalAuthentication/LocalAuthentication.h>

@implementation CMBiometricAuth

+ (LAPolicy)laPolicyFor:(CMBiometricPolicy)policy {
    return (policy == CMBiometricPolicyDestructive)
        ? LAPolicyDeviceOwnerAuthentication
        : LAPolicyDeviceOwnerAuthenticationWithBiometrics;
}

+ (BOOL)isAvailable {
    LAContext *ctx = [LAContext new];
    NSError *err = nil;
    BOOL can = [ctx canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                                error:&err];
    return can;
}

+ (void)evaluatePolicy:(CMBiometricPolicy)policy
                reason:(NSString *)reason
            completion:(CMBiometricCompletion)completion {
    LAContext *ctx = [LAContext new];
    NSError *canErr = nil;
    if (![ctx canEvaluatePolicy:[self laPolicyFor:policy] error:&canErr]) {
        NSError *out = [CMError errorWithCode:CMErrorCodeBiometricUnavailable
                                       message:@"Biometric authentication is not available"
                               underlyingError:canErr];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) { completion(NO, out); }
        });
        return;
    }
    [ctx evaluatePolicy:[self laPolicyFor:policy]
        localizedReason:(reason ?: @"Authenticate")
                  reply:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) { completion(success, error); }
        });
    }];
}

@end
