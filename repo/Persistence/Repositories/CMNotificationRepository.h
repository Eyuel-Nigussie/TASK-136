#import "CMRepository.h"
#import "CMNotificationItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMNotificationRepository : CMRepository
- (CMNotificationItem *)insertNotification;
- (nullable NSArray<CMNotificationItem *> *)unreadForUser:(NSString *)userId
                                                     limit:(NSUInteger)limit
                                                     error:(NSError **)error;
/// Returns all active notifications (read and unread) for a user.
- (nullable NSArray<CMNotificationItem *> *)allForUser:(NSString *)userId
                                                  limit:(NSUInteger)limit
                                                  error:(NSError **)error;
/// Rate-limit check: count of items in a specific bucket key.
- (NSUInteger)countInBucket:(NSString *)bucket error:(NSError **)error;
/// Global rate-limit: count ALL notifications for a tenant in a minute,
/// matching rateLimitBucket BEGINSWITH prefix AND ENDSWITH minuteSuffix.
- (NSUInteger)countInGlobalBucket:(NSString *)tenantPrefix
                     minuteSuffix:(NSString *)minuteSuffix
                            error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
