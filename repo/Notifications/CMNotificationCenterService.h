//
//  CMNotificationCenterService.h
//  CourierMatch
//
//  Main notification service: emit, render, rate-limit, coalesce, ack/read,
//  and optionally mirror to UNUserNotificationCenter.
//  See design.md §6, questions.md Q6.
//

#import <Foundation/Foundation.h>

@class CMNotificationItem;
@class CMNotificationRepository;
@class CMNotificationTemplateRenderer;
@class CMNotificationRateLimiter;

NS_ASSUME_NONNULL_BEGIN

/// Notification emitted on NSNotificationCenter when the unread count changes.
extern NSNotificationName const CMNotificationUnreadCountDidChangeNotification;

@interface CMNotificationCenterService : NSObject

/// Designated initializer. All dependencies are injectable for testability.
/// Pass nil to use defaults (shared singletons + viewContext-based repo).
- (instancetype)initWithRepository:(nullable CMNotificationRepository *)repository
                          renderer:(nullable CMNotificationTemplateRenderer *)renderer
                       rateLimiter:(nullable CMNotificationRateLimiter *)rateLimiter NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

#pragma mark - Emit

/// Full emission pipeline: render template -> check rate limit -> persist
/// (active or coalesced) -> create/update digest if needed -> optionally
/// mirror to UNUserNotificationCenter.
///
/// @param templateKey         One of: assigned, picked_up, delivered, dispute_opened.
/// @param tenantId            Explicit tenant ID — avoids ambient-context dependency.
/// @param payload             Dictionary for template variable resolution.
/// @param recipientUserId     The user who receives the notification.
/// @param subjectEntityType   Optional entity type (e.g. "Order", "Dispute").
/// @param subjectEntityId     Optional entity ID.
/// @param completion          Called on completion with the emitted item (or digest) and optional error.
///                            Called on the main thread.
- (void)emitNotificationForEvent:(NSString *)templateKey
                        tenantId:(NSString *)tenantId
                         payload:(nullable NSDictionary *)payload
                 recipientUserId:(NSString *)recipientUserId
               subjectEntityType:(nullable NSString *)subjectEntityType
                 subjectEntityId:(nullable NSString *)subjectEntityId
                      completion:(nullable void (^)(CMNotificationItem * _Nullable item, NSError * _Nullable error))completion;

#pragma mark - Read & Ack

/// Sets readAt on a notification. If the notification is a digest, cascades
/// readAt to all children.
/// @return YES on success; NO on error.
- (BOOL)markRead:(NSString *)notificationId error:(NSError **)error;

/// Sets ackedAt on a notification. If the notification is a digest, cascades
/// ackedAt to all children.
/// @return YES on success; NO on error.
- (BOOL)markAcknowledged:(NSString *)notificationId error:(NSError **)error;

#pragma mark - Queries

/// Returns the unread active notification count for the current user.
- (NSUInteger)unreadCountForCurrentUser;

/// Returns unread active notifications for the current user, ordered by
/// createdAt descending. Includes digest items.
/// @param limit Maximum number to return (0 = all).
- (nullable NSArray<CMNotificationItem *> *)unreadNotificationsForCurrentUser:(NSUInteger)limit
                                                                        error:(NSError **)error;

/// Returns all active notifications (read and unread) for the current user,
/// ordered by createdAt descending. Provides a history/archive view.
/// @param limit Maximum number to return (0 = all).
- (nullable NSArray<CMNotificationItem *> *)allNotificationsForCurrentUser:(NSUInteger)limit
                                                                     error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
