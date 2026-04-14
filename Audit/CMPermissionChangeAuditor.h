//
//  CMPermissionChangeAuditor.h
//  CourierMatch
//
//  Thin wrapper around CMAuditService for recording permission and role changes.
//  All actions use the "permission.*" prefix.
//  See design.md §10.3.
//

#import <Foundation/Foundation.h>

@class CMAuditEntry;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for permission audit operations.
typedef void (^CMPermissionAuditCompletion)(CMAuditEntry * _Nullable entry,
                                            NSError * _Nullable error);

@interface CMPermissionChangeAuditor : NSObject

+ (instancetype)shared;

/// Records a role change for a user.
/// Action: "permission.role_changed"
/// @param subjectUserId The user whose role changed.
/// @param oldRole       Previous role string.
/// @param newRole       New role string.
/// @param reason        Optional reason for the change.
/// @param completion    Called when the audit entry is persisted.
- (void)recordRoleChange:(NSString *)subjectUserId
                 oldRole:(NSString *)oldRole
                 newRole:(NSString *)newRole
                  reason:(nullable NSString *)reason
              completion:(nullable CMPermissionAuditCompletion)completion;

/// Records a permission grant.
/// Action: "permission.granted"
/// @param subjectUserId The user receiving the permission.
/// @param permission    The permission being granted.
/// @param reason        Optional reason.
/// @param completion    Called when the audit entry is persisted.
- (void)recordPermissionGrant:(NSString *)subjectUserId
                   permission:(NSString *)permission
                       reason:(nullable NSString *)reason
                   completion:(nullable CMPermissionAuditCompletion)completion;

/// Records a permission revocation.
/// Action: "permission.revoked"
/// @param subjectUserId The user losing the permission.
/// @param permission    The permission being revoked.
/// @param reason        Optional reason.
/// @param completion    Called when the audit entry is persisted.
- (void)recordPermissionRevoke:(NSString *)subjectUserId
                    permission:(NSString *)permission
                        reason:(nullable NSString *)reason
                    completion:(nullable CMPermissionAuditCompletion)completion;

/// Records a bulk permission update.
/// Action: "permission.bulk_updated"
/// @param subjectUserId The user whose permissions changed.
/// @param oldPerms      Dictionary of old permissions.
/// @param newPerms      Dictionary of new permissions.
/// @param reason        Optional reason.
/// @param completion    Called when the audit entry is persisted.
- (void)recordPermissionBulkUpdate:(NSString *)subjectUserId
                          oldPerms:(NSDictionary *)oldPerms
                          newPerms:(NSDictionary *)newPerms
                            reason:(nullable NSString *)reason
                        completion:(nullable CMPermissionAuditCompletion)completion;

@end

NS_ASSUME_NONNULL_END
