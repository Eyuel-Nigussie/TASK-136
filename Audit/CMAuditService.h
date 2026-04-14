//
//  CMAuditService.h
//  CourierMatch
//
//  Main audit service. Writes append-only audit entries with full hash-chain
//  linkage. Every significant action flows through this service.
//  See design.md §10.3.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMAuditEntry;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for asynchronous audit operations.
/// @param entry The created audit entry, or nil on failure.
/// @param error The error, or nil on success.
typedef void (^CMAuditServiceCompletion)(CMAuditEntry * _Nullable entry,
                                         NSError * _Nullable error);

@interface CMAuditService : NSObject

+ (instancetype)shared;

/// Records an audit action asynchronously on a background Core Data context.
/// The completion block is called on an arbitrary queue.
/// @param action     Action string (e.g., "order.assign", "appeal.decide").
/// @param targetType Optional target entity type (e.g., "Order", "User").
/// @param targetId   Optional target entity identifier.
/// @param beforeJSON Optional dictionary of the state before the action.
/// @param afterJSON  Optional dictionary of the state after the action.
/// @param reason     Optional human-readable reason.
/// @param completion Called when the entry has been persisted (or on failure).
- (void)recordAction:(NSString *)action
          targetType:(nullable NSString *)targetType
            targetId:(nullable NSString *)targetId
          beforeJSON:(nullable NSDictionary *)beforeJSON
           afterJSON:(nullable NSDictionary *)afterJSON
              reason:(nullable NSString *)reason
          completion:(nullable CMAuditServiceCompletion)completion;

/// Specialized method for permission/role changes.
/// Action is set to "permission.role_changed".
/// @param subjectUserId The user whose permissions are changing.
/// @param oldRole       The previous role.
/// @param newRole       The new role.
/// @param reason        Reason for the change.
/// @param completion    Called when the entry has been persisted (or on failure).
- (void)recordPermissionChangeForSubject:(NSString *)subjectUserId
                                 oldRole:(NSString *)oldRole
                                 newRole:(NSString *)newRole
                                  reason:(nullable NSString *)reason
                              completion:(nullable CMAuditServiceCompletion)completion;

/// Synchronous variant for use on background contexts that already have
/// their own managed object context. Caller is responsible for saving the context.
/// @param action     Action string.
/// @param targetType Optional target entity type.
/// @param targetId   Optional target entity identifier.
/// @param beforeJSON Optional state-before dictionary.
/// @param afterJSON  Optional state-after dictionary.
/// @param reason     Optional reason.
/// @param context    A background NSManagedObjectContext to use.
/// @param error      Set on failure.
/// @return The created CMAuditEntry, or nil on failure.
- (nullable CMAuditEntry *)recordActionSync:(NSString *)action
                                 targetType:(nullable NSString *)targetType
                                   targetId:(nullable NSString *)targetId
                                 beforeJSON:(nullable NSDictionary *)beforeJSON
                                  afterJSON:(nullable NSDictionary *)afterJSON
                                     reason:(nullable NSString *)reason
                                    context:(NSManagedObjectContext *)context
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
