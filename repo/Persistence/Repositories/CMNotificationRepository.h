#import "CMRepository.h"
#import "CMNotificationItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMNotificationRepository : CMRepository
- (CMNotificationItem *)insertNotification;
- (nullable NSArray<CMNotificationItem *> *)unreadForUser:(NSString *)userId
                                                     limit:(NSUInteger)limit
                                                     error:(NSError **)error;
/// Rate-limit check: count of items in the current minute bucket.
- (NSUInteger)countInBucket:(NSString *)bucket error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
