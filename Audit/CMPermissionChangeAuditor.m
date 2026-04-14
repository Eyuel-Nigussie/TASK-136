//
//  CMPermissionChangeAuditor.m
//  CourierMatch
//

#import "CMPermissionChangeAuditor.h"
#import "CMAuditService.h"
#import "CMAuditEntry.h"
#import "CMTenantContext.h"
#import "CMDebugLogger.h"

@implementation CMPermissionChangeAuditor

+ (instancetype)shared {
    static CMPermissionChangeAuditor *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMPermissionChangeAuditor new]; });
    return s;
}

#pragma mark - Role Changes

- (void)recordRoleChange:(NSString *)subjectUserId
                 oldRole:(NSString *)oldRole
                 newRole:(NSString *)newRole
                  reason:(NSString *)reason
              completion:(CMPermissionAuditCompletion)completion {

    CMTenantContext *tc = [CMTenantContext shared];

    NSDictionary *beforeJSON = @{
        @"role": oldRole ?: @"",
        @"subjectUserId": subjectUserId ?: @"",
        @"actor": tc.currentUserId ?: @"",
    };
    NSDictionary *afterJSON = @{
        @"role": newRole ?: @"",
        @"subjectUserId": subjectUserId ?: @"",
        @"actor": tc.currentUserId ?: @"",
    };

    [[CMAuditService shared] recordAction:@"permission.role_changed"
                               targetType:@"User"
                                 targetId:subjectUserId
                               beforeJSON:beforeJSON
                                afterJSON:afterJSON
                                   reason:reason
                               completion:completion];
}

#pragma mark - Permission Grant

- (void)recordPermissionGrant:(NSString *)subjectUserId
                   permission:(NSString *)permission
                       reason:(NSString *)reason
                   completion:(CMPermissionAuditCompletion)completion {

    CMTenantContext *tc = [CMTenantContext shared];

    NSDictionary *afterJSON = @{
        @"permission": permission ?: @"",
        @"subjectUserId": subjectUserId ?: @"",
        @"actor": tc.currentUserId ?: @"",
        @"granted": @YES,
    };

    [[CMAuditService shared] recordAction:@"permission.granted"
                               targetType:@"User"
                                 targetId:subjectUserId
                               beforeJSON:nil
                                afterJSON:afterJSON
                                   reason:reason
                               completion:completion];
}

#pragma mark - Permission Revoke

- (void)recordPermissionRevoke:(NSString *)subjectUserId
                    permission:(NSString *)permission
                        reason:(NSString *)reason
                    completion:(CMPermissionAuditCompletion)completion {

    CMTenantContext *tc = [CMTenantContext shared];

    NSDictionary *beforeJSON = @{
        @"permission": permission ?: @"",
        @"subjectUserId": subjectUserId ?: @"",
        @"actor": tc.currentUserId ?: @"",
        @"granted": @YES,
    };
    NSDictionary *afterJSON = @{
        @"permission": permission ?: @"",
        @"subjectUserId": subjectUserId ?: @"",
        @"actor": tc.currentUserId ?: @"",
        @"granted": @NO,
    };

    [[CMAuditService shared] recordAction:@"permission.revoked"
                               targetType:@"User"
                                 targetId:subjectUserId
                               beforeJSON:beforeJSON
                                afterJSON:afterJSON
                                   reason:reason
                               completion:completion];
}

#pragma mark - Bulk Permission Update

- (void)recordPermissionBulkUpdate:(NSString *)subjectUserId
                          oldPerms:(NSDictionary *)oldPerms
                          newPerms:(NSDictionary *)newPerms
                            reason:(NSString *)reason
                        completion:(CMPermissionAuditCompletion)completion {

    [[CMAuditService shared] recordAction:@"permission.bulk_updated"
                               targetType:@"User"
                                 targetId:subjectUserId
                               beforeJSON:oldPerms
                                afterJSON:newPerms
                                   reason:reason
                               completion:completion];
}

@end
