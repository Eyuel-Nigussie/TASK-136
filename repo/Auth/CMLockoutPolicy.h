//
//  CMLockoutPolicy.h
//  CourierMatch
//
//  Failed-attempt policy per design.md §4.1:
//    - 3 failures → next attempt must pass CAPTCHA.
//    - 5 failures → account locked for 10 minutes.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMUserAccount;

@interface CMLockoutPolicy : NSObject

@property (class, nonatomic, readonly) NSUInteger captchaThreshold;   // 3
@property (class, nonatomic, readonly) NSUInteger lockoutThreshold;   // 5
@property (class, nonatomic, readonly) NSTimeInterval lockoutDuration; // 600

/// Registers a failed attempt on the given user, updating `failedAttempts`,
/// `status`, and `lockUntil` as appropriate. Does NOT save the context —
/// caller is responsible.
+ (void)applyFailureTo:(CMUserAccount *)user;

/// Clears the failure counters on successful authentication.
+ (void)applySuccessTo:(CMUserAccount *)user;

/// Returns YES iff the account is currently locked and `lockUntil` has not
/// yet elapsed. Also transitions `status` back to `active` if the lock has
/// expired (without saving — caller saves).
+ (BOOL)maybeClearExpiredLockOn:(CMUserAccount *)user;

@end

NS_ASSUME_NONNULL_END
