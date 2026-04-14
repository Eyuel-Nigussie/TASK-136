//
//  CMUserAccount.m
//  CourierMatch
//

#import "CMUserAccount.h"

NSString * const CMUserRoleCourier        = @"courier";
NSString * const CMUserRoleDispatcher     = @"dispatcher";
NSString * const CMUserRoleReviewer       = @"reviewer";
NSString * const CMUserRoleCustomerService = @"cs";
NSString * const CMUserRoleFinance        = @"finance";
NSString * const CMUserRoleAdmin          = @"admin";

NSString * const CMUserStatusActive       = @"active";
NSString * const CMUserStatusLocked       = @"locked";
NSString * const CMUserStatusDisabled     = @"disabled";
NSString * const CMUserStatusDeleted      = @"deleted";

@implementation CMUserAccount

@dynamic userId, tenantId, username, displayName;
@dynamic passwordHash, passwordSalt, passwordIterations, passwordUpdatedAt;
@dynamic role, status, failedAttempts, lockUntil;
@dynamic biometricEnabled, biometricRefId, lastLoginAt, forceLogoutAt;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;

- (BOOL)isCurrentlyLocked {
    if (![self.status isEqualToString:CMUserStatusLocked]) { return NO; }
    if (!self.lockUntil) { return NO; }
    return [self.lockUntil timeIntervalSinceNow] > 0;
}

- (BOOL)requiresCaptchaNextAttempt {
    return self.failedAttempts >= 3 && ![self isCurrentlyLocked];
}

@end
