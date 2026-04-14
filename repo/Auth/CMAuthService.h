//
//  CMAuthService.h
//  CourierMatch
//
//  High-level orchestrator that coordinates:
//    - password hashing (CMPasswordHasher)
//    - password policy (CMPasswordPolicy)
//    - lockout + CAPTCHA gating (CMLockoutPolicy, CMCaptchaService)
//    - login-history recording (CMLoginHistoryRepository)
//    - biometric re-auth (CMBiometricAuth)
//    - session establishment (CMSessionManager) — bound after auth succeeds
//
//  All mutation happens on a background context. Completion blocks run on
//  the main thread.
//

#import <Foundation/Foundation.h>
#import "CMAuthProvider.h"

NS_ASSUME_NONNULL_BEGIN

@class CMUserAccount, CMCaptchaChallenge;

typedef void (^CMAuthSignupCompletion)(CMUserAccount * _Nullable user, NSError * _Nullable error);

typedef NS_ENUM(NSInteger, CMAuthStepOutcome) {
    CMAuthStepOutcomeSucceeded         = 0,
    CMAuthStepOutcomeFailed            = 1,
    CMAuthStepOutcomeLocked            = 2,
    CMAuthStepOutcomeCaptchaRequired   = 3,   // caller must solve CAPTCHA and retry
    CMAuthStepOutcomeCaptchaFailed     = 4,
    CMAuthStepOutcomePasswordPolicy    = 5,
};

/// Caller-facing outcome bundle.
@interface CMAuthAttemptResult : NSObject
@property (nonatomic, assign) CMAuthStepOutcome outcome;
@property (nonatomic, strong, nullable) CMUserAccount *user;
@property (nonatomic, strong, nullable) CMCaptchaChallenge *pendingCaptcha;
@property (nonatomic, strong, nullable) NSError *error;
@end

typedef void (^CMAuthAttemptCompletion)(CMAuthAttemptResult *result);

@interface CMAuthService : NSObject

+ (instancetype)shared;

#pragma mark - Signup

/// Creates a new UserAccount. Enforces CMPasswordPolicy.
/// NOTE: In this offline build, signup is gated by admin elsewhere; this
/// method is the single seam that callers use.
- (void)signupWithTenantId:(NSString *)tenantId
                   username:(NSString *)username
                   password:(NSString *)password
                displayName:(nullable NSString *)displayName
                       role:(NSString *)role
                 completion:(CMAuthSignupCompletion)completion;

#pragma mark - Login

/// Full password login with CAPTCHA handling.
///
/// `captchaChallengeId` + `captchaAnswer` are only consulted when the user's
/// prior failure count >= 3 (Q10 / §4.1). If a CAPTCHA is required and the
/// caller did not supply one, the result's `pendingCaptcha` carries a freshly
/// issued challenge; the caller must render it and re-invoke this method
/// with the answer filled in.
- (void)loginWithTenantId:(NSString *)tenantId
                  username:(NSString *)username
                  password:(NSString *)password
         captchaChallengeId:(nullable NSString *)captchaChallengeId
              captchaAnswer:(nullable NSString *)captchaAnswer
                 completion:(CMAuthAttemptCompletion)completion;

#pragma mark - Biometric

/// Evaluates biometrics, then retrieves the per-user session token from the
/// Keychain and reconstitutes a session. If the user has not previously
/// opted-in or the LAContext evaluation fails, returns `CMAuthStepOutcomeFailed`.
- (void)loginWithBiometricsForUserId:(NSString *)userId
                           completion:(CMAuthAttemptCompletion)completion;

/// Re-prompts biometrics for destructive actions (account deletion, unmask,
/// unsigned export). Must be called before the action proceeds.
- (void)reauthForDestructiveActionWithReason:(NSString *)reason
                                   completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
