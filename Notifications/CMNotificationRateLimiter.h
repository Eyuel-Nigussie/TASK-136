//
//  CMNotificationRateLimiter.h
//  CourierMatch
//
//  Enforces the 5-per-minute rate limit per (tenantId, templateKey) bucket.
//  Bucket key = "tenantId:templateKey:floor(unixTime/60)".
//  See design.md §6.2, questions.md Q6.
//

#import <Foundation/Foundation.h>

@class CMNotificationRepository;

NS_ASSUME_NONNULL_BEGIN

/// Result of a rate-limit check.
typedef NS_ENUM(NSInteger, CMRateLimitDecision) {
    /// Under the limit — emit as a normal active notification.
    CMRateLimitDecisionAllow = 0,
    /// At or above the limit — the notification must be coalesced into a digest.
    CMRateLimitDecisionCoalesce = 1,
};

@interface CMNotificationRateLimiter : NSObject

- (instancetype)initWithRepository:(CMNotificationRepository *)repository NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The maximum number of active notifications allowed per minute per bucket.
@property (class, nonatomic, readonly) NSUInteger maxPerMinute;

/// The maximum number of minutes a rolling digest can span before a new digest
/// is created (per Q6).
@property (class, nonatomic, readonly) NSUInteger maxDigestMinutes;

/// Builds the bucket key string for the given parameters.
/// Format: "tenantId:templateKey:minuteBucket"
+ (NSString *)bucketKeyForTenantId:(NSString *)tenantId
                       templateKey:(NSString *)templateKey
                              date:(NSDate *)date;

/// Returns the minute-bucket integer (floor(unixTime / 60)) for a given date.
+ (int64_t)minuteBucketForDate:(NSDate *)date;

/// Checks whether a new notification for the given bucket would exceed the
/// rate limit. Uses the repository's countInBucket: to query persisted counts.
///
/// @param tenantId     Current tenant.
/// @param templateKey  The notification template key.
/// @param date         Emission timestamp (typically [NSDate date]).
/// @param error        Set on Core Data fetch errors.
/// @return CMRateLimitDecisionAllow or CMRateLimitDecisionCoalesce.
- (CMRateLimitDecision)checkLimitForTenantId:(NSString *)tenantId
                                 templateKey:(NSString *)templateKey
                                        date:(NSDate *)date
                                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
