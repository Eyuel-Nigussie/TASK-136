//
//  CMAccountService.m
//  CourierMatch
//

#import "CMAccountService.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"
#import "CMAuditService.h"
#import "CMError.h"
#import "CMDebugLogger.h"

@interface CMAccountService ()
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMAccountService

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    self = [super init];
    if (self) {
        _context = context;
    }
    return self;
}

- (BOOL)deleteAccount:(CMUserAccount *)user error:(NSError **)error {
    NSParameterAssert(user);

    // 1. Authentication check.
    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"No authenticated user for account deletion"];
        }
        return NO;
    }

    // 2. Admin role enforcement.
    if (![tc.currentRole isEqualToString:CMUserRoleAdmin]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only admins may delete user accounts"];
        }
        return NO;
    }

    // 3. Tenant ownership check: target user must belong to current admin's tenant.
    if (!user.tenantId || ![user.tenantId isEqualToString:tc.currentTenantId]) {
        // Audit the cross-tenant denial attempt for compliance traceability.
        [[CMAuditService shared] recordAction:@"user.account_deletion_denied"
                                   targetType:@"UserAccount"
                                     targetId:user.userId
                                   beforeJSON:nil
                                    afterJSON:@{@"reason": @"cross-tenant deletion attempt",
                                                @"targetTenantId": user.tenantId ?: @"",
                                                @"actorTenantId": tc.currentTenantId ?: @""}
                                       reason:@"Cross-tenant deletion blocked"
                                   completion:nil];
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Cannot delete a user from a different tenant"];
        }
        return NO;
    }

    // 4. Prevent self-deletion.
    if ([tc.currentUserId isEqualToString:user.userId]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Cannot delete your own account"];
        }
        return NO;
    }

    // 5. Prevent double-deletion.
    if ([user.status isEqualToString:CMUserStatusDeleted]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Account is already deleted"];
        }
        return NO;
    }

    // 6. Soft-delete: set status to deleted, deletedAt, and force logout.
    NSString *oldStatus = user.status;
    user.status = CMUserStatusDeleted;
    user.deletedAt = [NSDate date];
    user.forceLogoutAt = [NSDate date];
    user.updatedAt = [NSDate date];

    NSError *saveErr = nil;
    if (![self.context save:&saveErr]) {
        // Revert on failure.
        user.status = oldStatus;
        user.deletedAt = nil;
        user.forceLogoutAt = nil;
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeCoreDataSaveFailed
                                    message:@"Failed to save account deletion"
                            underlyingError:saveErr];
        }
        return NO;
    }

    // 7. Audit trail.
    [[CMAuditService shared] recordAction:@"user.account_deleted"
                               targetType:@"UserAccount"
                                 targetId:user.userId
                               beforeJSON:@{@"status": oldStatus, @"userId": user.userId}
                                afterJSON:@{@"status": CMUserStatusDeleted,
                                            @"deletedAt": [user.deletedAt description]}
                                   reason:@"Admin account deletion"
                               completion:nil];

    CMLogInfo(@"account.service", @"Deleted account %@ (was %@)",
              [CMDebugLogger redact:user.userId], oldStatus);

    return YES;
}

@end
