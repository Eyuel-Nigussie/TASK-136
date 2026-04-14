//
//  CMLockoutPolicy.m
//  CourierMatch
//

#import "CMLockoutPolicy.h"
#import "CMUserAccount.h"

@implementation CMLockoutPolicy

+ (NSUInteger)captchaThreshold    { return 3; }
+ (NSUInteger)lockoutThreshold    { return 5; }
+ (NSTimeInterval)lockoutDuration { return 600.0; }

+ (void)applyFailureTo:(CMUserAccount *)user {
    if (!user) { return; }
    user.failedAttempts = (int16_t)(user.failedAttempts + 1);
    if ((NSUInteger)user.failedAttempts >= [self lockoutThreshold]) {
        user.status    = CMUserStatusLocked;
        user.lockUntil = [NSDate dateWithTimeIntervalSinceNow:[self lockoutDuration]];
    }
    user.updatedAt = [NSDate date];
}

+ (void)applySuccessTo:(CMUserAccount *)user {
    if (!user) { return; }
    user.failedAttempts = 0;
    user.lockUntil      = nil;
    if ([user.status isEqualToString:CMUserStatusLocked]) {
        user.status = CMUserStatusActive;
    }
    user.lastLoginAt = [NSDate date];
    user.updatedAt   = user.lastLoginAt;
}

+ (BOOL)maybeClearExpiredLockOn:(CMUserAccount *)user {
    if (!user) { return NO; }
    if (![user.status isEqualToString:CMUserStatusLocked]) { return NO; }
    if (!user.lockUntil) { return NO; }
    if ([user.lockUntil timeIntervalSinceNow] > 0) { return NO; }
    // Lock expired — unlock but keep the failure counter so next failure is
    // immediately CAPTCHA-gated.
    user.status    = CMUserStatusActive;
    user.lockUntil = nil;
    user.updatedAt = [NSDate date];
    return YES;
}

@end
