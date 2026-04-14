//
//  CMNotificationRateLimiter.m
//  CourierMatch
//

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
    int64_t bucket = [self minuteBucketForDate:date];
    return [NSString stringWithFormat:@"%@:%@:%lld", tenantId, templateKey, bucket];
}

#pragma mark - Rate-limit check

- (CMRateLimitDecision)checkLimitForTenantId:(NSString *)tenantId
                                 templateKey:(NSString *)templateKey
                                        date:(NSDate *)date
                                       error:(NSError **)error {
    NSString *bucketKey = [[self class] bucketKeyForTenantId:tenantId
                                                 templateKey:templateKey
                                                        date:date];

    NSError *fetchError = nil;
    NSUInteger count = [self.repository countInBucket:bucketKey error:&fetchError];
    if (fetchError) {
        CMLogError(kTag, @"bucket count fetch failed for '%@': %@", bucketKey, fetchError);
        if (error) { *error = fetchError; }
        // On error, default to allow so we don't silently drop.
        return CMRateLimitDecisionAllow;
    }

    if (count >= kMaxPerMinute) {
        CMLogInfo(kTag, @"rate limit reached for bucket '%@' (count=%lu, max=%lu)",
                  bucketKey, (unsigned long)count, (unsigned long)kMaxPerMinute);
        return CMRateLimitDecisionCoalesce;
    }

    CMLogInfo(kTag, @"within limit for bucket '%@' (count=%lu/%lu)",
              bucketKey, (unsigned long)count, (unsigned long)kMaxPerMinute);
    return CMRateLimitDecisionAllow;
}

@end
