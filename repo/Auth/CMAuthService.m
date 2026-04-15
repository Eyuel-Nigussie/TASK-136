//
//  CMAuthService.m
//  CourierMatch
//

#import "CMAuthService.h"
#import "CMAuthProvider.h"
#import "CMPasswordPolicy.h"
#import "CMPasswordHasher.h"
#import "CMLockoutPolicy.h"
#import "CMCaptchaChallenge.h"
#import "CMBiometricAuth.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"
#import "CMLoginHistory.h"
#import "CMUserRepository.h"
#import "CMLoginHistoryRepository.h"
#import "CMCoreDataStack.h"
#import "CMKeychain.h"
#import "CMKeychainKeys.h"
#import "CMTenantContext.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMAuthAttemptResult
@end

@implementation CMAuthService

+ (instancetype)shared {
    static CMAuthService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMAuthService new]; });
    return s;
}

#pragma mark - Helpers

- (void)postMainCompletion:(void (^)(void))block {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (block) { block(); }
    });
}

- (CMAuthAttemptResult *)resultWithOutcome:(CMAuthStepOutcome)o
                                       user:(CMUserAccount *)user
                                      error:(NSError *)err
                             pendingCaptcha:(CMCaptchaChallenge *)cap {
    CMAuthAttemptResult *r = [CMAuthAttemptResult new];
    r.outcome = o;
    r.user = user;
    r.error = err;
    r.pendingCaptcha = cap;
    return r;
}

#pragma mark - Signup

- (void)signupWithTenantId:(NSString *)tenantId
                   username:(NSString *)username
                   password:(NSString *)password
                displayName:(NSString *)displayName
                       role:(NSString *)role
                 completion:(CMAuthSignupCompletion)completion {

    // Security: self-service signup is restricted to the "courier" role.
    // Only an authenticated admin may create accounts with privileged roles
    // (dispatcher, reviewer, customer_service, finance, admin).
    NSString *effectiveRole = role ?: CMUserRoleCourier;
    if (![effectiveRole isEqualToString:CMUserRoleCourier]) {
        CMTenantContext *tc = [CMTenantContext shared];
        if (!tc.isAuthenticated || ![tc.currentRole isEqualToString:CMUserRoleAdmin]) {
            NSError *err = [CMError errorWithCode:CMErrorCodePermissionDenied
                                           message:@"Only administrators may create non-courier accounts"];
            [self postMainCompletion:^{ if (completion) { completion(nil, err); } }];
            return;
        }
    }

    CMPasswordPolicy *policy = [CMPasswordPolicy shared];
    CMPasswordViolation v = [policy evaluate:password];
    if (v != CMPasswordViolationNone) {
        NSError *err = [CMError errorWithCode:CMErrorCodePasswordPolicyViolation
                                       message:[policy summaryForViolations:v]];
        [self postMainCompletion:^{ if (completion) { completion(nil, err); } }];
        return;
    }

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:ctx];

        NSError *lookupErr = nil;
        CMUserAccount *existing = [repo preAuthLookupWithTenantId:tenantId
                                                          username:username
                                                             error:&lookupErr];
        if (existing) {
            NSError *err = [CMError errorWithCode:CMErrorCodeUniqueConstraintViolated
                                          message:@"Username already exists for this tenant"];
            [self postMainCompletion:^{ if (completion) { completion(nil, err); } }];
            return;
        }

        NSData *salt = [CMPasswordHasher generateSalt];
        NSUInteger iters = CMPasswordHasherDefaultIterations;
        NSData *hash = [CMPasswordHasher hashPassword:password
                                                  salt:salt
                                           iterations:iters];
        if (!hash) {
            NSError *err = [CMError errorWithCode:CMErrorCodeCryptoOperationFailed
                                          message:@"Password hashing failed"];
            [self postMainCompletion:^{ if (completion) { completion(nil, err); } }];
            return;
        }

        NSDate *now = [NSDate date];
        CMUserAccount *u = [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                                         inManagedObjectContext:ctx];
        u.userId             = [[NSUUID UUID] UUIDString];
        u.tenantId           = tenantId;
        u.username           = username;
        u.displayName        = displayName;
        u.passwordHash       = hash;
        u.passwordSalt       = salt;
        u.passwordIterations = (int64_t)iters;
        u.passwordUpdatedAt  = now;
        u.role               = role ?: CMUserRoleCourier;
        u.status             = CMUserStatusActive;
        u.failedAttempts     = 0;
        u.biometricEnabled   = NO;
        u.createdAt          = now;
        u.updatedAt          = now;
        u.createdBy          = [CMTenantContext shared].currentUserId;
        u.updatedBy          = u.createdBy;
        u.version            = 1;

        NSError *saveErr = nil;
        if (![ctx cm_saveWithError:&saveErr]) {
            [self postMainCompletion:^{ if (completion) { completion(nil, saveErr); } }];
            return;
        }

        NSManagedObjectID *oid = u.objectID;
        [self postMainCompletion:^{
            CMUserAccount *mainView = (CMUserAccount *)[[CMCoreDataStack shared].viewContext objectWithID:oid];
            if (completion) { completion(mainView, nil); }
        }];
    }];
}

#pragma mark - Password login

- (void)loginWithTenantId:(NSString *)tenantId
                  username:(NSString *)username
                  password:(NSString *)password
         captchaChallengeId:(NSString *)captchaChallengeId
              captchaAnswer:(NSString *)captchaAnswer
                 completion:(CMAuthAttemptCompletion)completion {

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:ctx];
        CMLoginHistoryRepository *hist = [[CMLoginHistoryRepository alloc] initWithContext:ctx];

        NSError *lookupErr = nil;
        CMUserAccount *u = [repo preAuthLookupWithTenantId:tenantId
                                                  username:username
                                                     error:&lookupErr];
        if (!u) {
            // Record without a userId binding; still captured for device history.
            [hist recordEntryForUserId:@"" tenantId:(tenantId ?: @"") outcome:CMLoginOutcomeFailed];
            [ctx cm_saveWithError:NULL];
            NSError *err = [CMError errorWithCode:CMErrorCodeAuthInvalidCredentials
                                          message:@"Invalid credentials"];
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                 user:nil
                                                                error:err
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }

        // Auto-unlock if the 10-min window has elapsed — the user can proceed
        // but still owes a CAPTCHA on this attempt because failedAttempts >= 3.
        [CMLockoutPolicy maybeClearExpiredLockOn:u];

        if ([u isCurrentlyLocked]) {
            [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:CMLoginOutcomeLocked];
            [ctx cm_saveWithError:NULL];
            NSError *err = [CMError errorWithCode:CMErrorCodeAuthAccountLocked
                                          message:@"Account is temporarily locked"];
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeLocked
                                                                 user:nil
                                                                error:err
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }

        if ([u requiresCaptchaNextAttempt]) {
            // Need a CAPTCHA; either verify the one supplied or issue a new one.
            if (captchaChallengeId.length == 0 || captchaAnswer.length == 0) {
                CMCaptchaChallenge *c = [[CMCaptchaService shared] issueChallenge];
                [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:CMLoginOutcomeCaptchaGated];
                [ctx cm_saveWithError:NULL];
                NSError *err = [CMError errorWithCode:CMErrorCodeAuthCaptchaRequired
                                              message:@"Please solve the CAPTCHA to continue"];
                [self postMainCompletion:^{
                    if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeCaptchaRequired
                                                                     user:nil
                                                                    error:err
                                                           pendingCaptcha:c]); }
                }];
                return;
            }
            if (![[CMCaptchaService shared] verifyChallengeId:captchaChallengeId
                                                        answer:captchaAnswer]) {
                [CMLockoutPolicy applyFailureTo:u];
                [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:CMLoginOutcomeCaptchaFailed];
                [ctx cm_saveWithError:NULL];
                NSError *err = [CMError errorWithCode:CMErrorCodeAuthCaptchaFailed
                                              message:@"CAPTCHA answer was incorrect"];
                // Issue a fresh CAPTCHA so the caller can retry.
                CMCaptchaChallenge *next = [[CMCaptchaService shared] issueChallenge];
                [self postMainCompletion:^{
                    if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeCaptchaFailed
                                                                     user:nil
                                                                    error:err
                                                           pendingCaptcha:next]); }
                }];
                return;
            }
            // CAPTCHA passed — fall through to password check.
        }

        // Verify password.
        BOOL ok = [CMPasswordHasher verifyPassword:password
                                               salt:u.passwordSalt
                                        iterations:(NSUInteger)u.passwordIterations
                                       expectedHash:u.passwordHash];
        if (!ok) {
            [CMLockoutPolicy applyFailureTo:u];
            NSString *outcome = [u isCurrentlyLocked] ? CMLoginOutcomeLocked
                                                       : CMLoginOutcomeFailed;
            [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:outcome];
            [ctx cm_saveWithError:NULL];

            BOOL nowLocked = [u isCurrentlyLocked];
            CMAuthStepOutcome code = nowLocked ? CMAuthStepOutcomeLocked : CMAuthStepOutcomeFailed;
            NSError *err = [CMError errorWithCode:(nowLocked ? CMErrorCodeAuthAccountLocked
                                                              : CMErrorCodeAuthInvalidCredentials)
                                           message:(nowLocked ? @"Account is now locked"
                                                              : @"Invalid credentials")];
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:code
                                                                 user:nil
                                                                error:err
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }

        // Success.
        [CMLockoutPolicy applySuccessTo:u];
        [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:CMLoginOutcomeSuccess];

        NSError *saveErr = nil;
        if (![ctx cm_saveWithError:&saveErr]) {
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                 user:nil
                                                                error:saveErr
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }

        NSManagedObjectID *oid = u.objectID;
        [self postMainCompletion:^{
            CMUserAccount *mainUser = (CMUserAccount *)[[CMCoreDataStack shared].viewContext objectWithID:oid];
            // Populate TenantContext and open a session (15-min idle timer).
            [[CMTenantContext shared] setUserId:mainUser.userId
                                        tenantId:mainUser.tenantId
                                            role:mainUser.role];
            [[CMSessionManager shared] openSessionForUser:mainUser];
            if (completion) {
                completion([self resultWithOutcome:CMAuthStepOutcomeSucceeded
                                              user:mainUser
                                             error:nil
                                    pendingCaptcha:nil]);
            }
        }];
    }];
}

#pragma mark - Biometric login

- (void)loginWithBiometricsForUserId:(NSString *)userId
                           completion:(CMAuthAttemptCompletion)completion {
    if (![CMBiometricAuth isAvailable]) {
        NSError *err = [CMError errorWithCode:CMErrorCodeBiometricUnavailable
                                       message:@"Biometrics are not available on this device"];
        [self postMainCompletion:^{
            if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                             user:nil
                                                            error:err
                                                   pendingCaptcha:nil]); }
        }];
        return;
    }
    [CMBiometricAuth evaluatePolicy:CMBiometricPolicyStandard
                             reason:@"Sign in to CourierMatch"
                         completion:^(BOOL success, NSError * _Nullable laErr) {
        if (!success) {
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                 user:nil
                                                                error:laErr
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }
        // Fetch the keychain-held session re-issue token for this user.
        NSString *key = [CMKeychainKey_SessionTokenPrefix stringByAppendingString:userId];
        NSData *token = [CMKeychain dataForKey:key error:NULL];
        if (!token) {
            NSError *err = [CMError errorWithCode:CMErrorCodeAuthSessionExpired
                                           message:@"No biometric session enrolled"];
            [self postMainCompletion:^{
                if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                 user:nil
                                                                error:err
                                                       pendingCaptcha:nil]); }
            }];
            return;
        }
        [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
            CMUserRepository *repo = [[CMUserRepository alloc] initWithContext:ctx];
            NSError *err = nil;
            CMUserAccount *u = nil;
            // Pre-auth: direct fetch by userId across tenants.
            NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"UserAccount"];
            req.predicate = [NSPredicate predicateWithFormat:@"userId == %@ AND deletedAt == nil", userId];
            req.fetchLimit = 1;
            u = [[ctx executeFetchRequest:req error:&err] firstObject];
            if (!u || ![u.status isEqualToString:CMUserStatusActive]) {
                NSError *e = [CMError errorWithCode:CMErrorCodeAuthInvalidCredentials
                                            message:@"User unavailable"];
                [self postMainCompletion:^{
                    if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                     user:nil
                                                                    error:e
                                                           pendingCaptcha:nil]); }
                }];
                return;
            }
            // Biometric enrollment-state enforcement: user must have explicitly
            // enrolled biometric login AND the keychain key must match the
            // recorded biometricRefId. A bare keychain token is not sufficient.
            if (!u.biometricEnabled ||
                !u.biometricRefId ||
                ![u.biometricRefId isEqualToString:key]) {
                NSError *e = [CMError errorWithCode:CMErrorCodeAuthInvalidCredentials
                                            message:@"Biometric login not enrolled for this account"];
                [self postMainCompletion:^{
                    if (completion) { completion([self resultWithOutcome:CMAuthStepOutcomeFailed
                                                                     user:nil
                                                                    error:e
                                                           pendingCaptcha:nil]); }
                }];
                return;
            }
            CMLoginHistoryRepository *hist = [[CMLoginHistoryRepository alloc] initWithContext:ctx];
            [CMLockoutPolicy applySuccessTo:u];
            [hist recordEntryForUserId:u.userId tenantId:u.tenantId outcome:CMLoginOutcomeSuccess];
            [ctx cm_saveWithError:NULL];

            NSManagedObjectID *oid = u.objectID;
            [self postMainCompletion:^{
                CMUserAccount *mu = (CMUserAccount *)[[CMCoreDataStack shared].viewContext objectWithID:oid];
                [[CMTenantContext shared] setUserId:mu.userId
                                            tenantId:mu.tenantId
                                                role:mu.role];
                [[CMSessionManager shared] openSessionForUser:mu];
                if (completion) {
                    completion([self resultWithOutcome:CMAuthStepOutcomeSucceeded
                                                  user:mu
                                                 error:nil
                                        pendingCaptcha:nil]);
                }
            }];
            (void)repo;
        }];
    }];
}

- (void)reauthForDestructiveActionWithReason:(NSString *)reason
                                   completion:(void (^)(BOOL, NSError * _Nullable))completion {
    [CMBiometricAuth evaluatePolicy:CMBiometricPolicyDestructive
                             reason:reason
                         completion:completion];
}

@end
