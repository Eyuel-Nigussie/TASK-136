//
//  CMCaptchaChallenge.h
//  CourierMatch
//
//  Arithmetic CAPTCHA gate per questions.md Q10.
//
//  - Questions are simple two-operand arithmetic rendered by the UI.
//  - Expected answer is held as HMAC-SHA256(nonce, answerString).
//  - The nonce lives ONLY in memory (never persisted). App restart
//    invalidates outstanding challenges — acceptable by design.
//  - The CAPTCHA's threat model is "slow a human tapping the login UI
//    on an unlocked device," not adversarial robustness.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMCaptchaChallenge : NSObject

@property (nonatomic, copy, readonly) NSString *challengeId;
@property (nonatomic, copy, readonly) NSString *question;   // e.g. "7 + 4"
@property (nonatomic, strong, readonly) NSDate *expiresAt;  // 60 s after creation

@end

@interface CMCaptchaService : NSObject

+ (instancetype)shared;

/// Generates a new challenge and retains it in memory until expiry.
- (CMCaptchaChallenge *)issueChallenge;

/// Returns YES iff the `answer` matches the challenge identified by `challengeId`.
/// Correct or expired challenges are consumed (single-use).
- (BOOL)verifyChallengeId:(NSString *)challengeId answer:(NSString *)answer;

/// Drops expired entries; invoked opportunistically from issue/verify.
- (void)sweepExpired;

@end

NS_ASSUME_NONNULL_END
