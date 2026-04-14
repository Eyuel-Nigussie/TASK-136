//
//  CMNotificationRateLimiter.m
//  CourierMatch
//
//  Enforces a strict global 5-per-minute cap per tenant (across ALL template
//  keys). Fail-closed: on errors, defaults to Coalesce to preserve the cap.

#import "CMNotificationRateLimiter.h"
#import "CMNotificationRepository.h"
#import "CMDebugLogger.h"

static NSString * const kTag = @"notif.ratelimit";
static NSUInteger const kMaxPerMinute     = 5;
static NSUInteger const kMaxDigestMinutes = 15;

@interface CMNotificationRateLimiter ()
@property (nonatomic, strong) CMNotificationRepository *repository;
@end

@implementation CMNotificationRateLimiter

+ (NSUInteger)maxPerMinute     { return kMaxPerMinute; }
+ (NSUInteger)maxDigestMinutes { return kMaxDigestMinutes; }

- (instancetype)initWithRepository:(CMNotificationRepository *)repository {
    if ((self = [super init])) {
        _repository = repository;
    }
    return self;
}

#pragma mark - Bucket key

+ (int64_t)minuteBucketForDate:(NSDate *)date {
    return (int64_t)floor([date timeIntervalSince1970] / 60.0);
}

+ (NSString *)bucketKeyForTenantId:(NSString *)tenantId
                       templateKey:(NSString *)templateKey
                              date:(NSDate *)date {
    // Include templateKey for per-notification tracking but the cap is global.
    int64_t bucket = [self minuteBucketForDate:date];
    return [NSString stringWithFormat:@"%@:%@:%lld", tenantId, templateKey, bucket];
}

/// Global bucket key: tenant + minute (no templateKey).
+ (NSString *)globalBucketPrefixForTenantId:(NSString *)tenantId
                                        date:(NSDate *)date {
    int64_t bucket = [self minuteBucketForDate:date];
    return [NSString stringWithFormat:@"%@:%%:%lld", tenantId, bucket];
}

#pragma mark - Rate-limit check

- (CMRateLimitDecision)checkLimitForTenantId:(NSString *)tenantId
                                 templateKey:(NSString *)templateKey
                                        date:(NSDate *)date
                                       error:(NSError **)error {
    // Global cap: count ALL notifications for this tenant in this minute,
    // regardless of templateKey. This enforces the strict "max 5 announcements
    // per minute" requirement from the prompt.
    int64_t minuteBucket = [[self class] minuteBucketForDate:date];
    NSString *globalPrefix = [NSString stringWithFormat:@"%@:", tenantId];
    NSString *minuteSuffix = [NSString stringWithFormat:@":%lld", minuteBucket];

    NSError *fetchError = nil;
    NSUInteger count = [self.repository countInGlobalBucket:globalPrefix
                                              minuteSuffix:minuteSuffix
                                                     error:&fetchError];
    if (fetchError) {
        CMLogError(kTag, @"global bucket count failed for tenant %@: %@",
                   [CMDebugLogger redact:tenantId], fetchError);
        if (error) { *error = fetchError; }
        // FAIL-CLOSED: coalesce when we can't confirm we're under the cap.
        return CMRateLimitDecisionCoalesce;
    }

    if (count >= kMaxPerMinute) {
        CMLogInfo(kTag, @"global rate limit reached for tenant (count=%lu, max=%lu)",
                  (unsigned long)count, (unsigned long)kMaxPerMinute);
        return CMRateLimitDecisionCoalesce;
    }

    CMLogInfo(kTag, @"within global limit (count=%lu/%lu)",
              (unsigned long)count, (unsigned long)kMaxPerMinute);
    return CMRateLimitDecisionAllow;
}

@end
