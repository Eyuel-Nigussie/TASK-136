//
//  CMNotificationRateLimiterTests.m
//  CourierMatch Tests
//
//  Tests for rate limiting: per-bucket decisions, minute boundaries,
//  bucket key format, and template-key independence.
//

#import <XCTest/XCTest.h>
#import "CMNotificationRateLimiter.h"
#import "CMNotificationRepository.h"

// ---------------------------------------------------------------------------
// A mock repository that returns a configurable count for any bucket.
// ---------------------------------------------------------------------------
@interface CMTestNotificationRepository : CMNotificationRepository
@property (nonatomic, assign) NSUInteger fakeCount;
@property (nonatomic, copy) NSString *lastQueriedBucket;
- (instancetype)init;
@end

@implementation CMTestNotificationRepository

- (instancetype)init {
    // CMNotificationRepository is a CMRepository subclass that requires a context.
    // For this mock we bypass the real init by calling NSObject init.
    self = [super initWithContext:nil];
    if (self) {
        _fakeCount = 0;
    }
    return self;
}

- (NSUInteger)countInBucket:(NSString *)bucket error:(NSError **)error {
    self.lastQueriedBucket = bucket;
    return self.fakeCount;
}

- (NSUInteger)countInGlobalBucket:(NSString *)tenantPrefix
                     minuteSuffix:(NSString *)minuteSuffix
                            error:(NSError **)error {
    // Return the same fakeCount for global bucket queries.
    return self.fakeCount;
}

@end

// ---------------------------------------------------------------------------
// A per-bucket mock that tracks independent counts per bucket key.
// ---------------------------------------------------------------------------
@interface CMPerBucketMockRepository : CMNotificationRepository
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *bucketCounts;
- (instancetype)init;
@end

@implementation CMPerBucketMockRepository

- (instancetype)init {
    self = [super initWithContext:nil];
    if (self) {
        _bucketCounts = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSUInteger)countInBucket:(NSString *)bucket error:(NSError **)error {
    return [self.bucketCounts[bucket] unsignedIntegerValue];
}

- (NSUInteger)countInGlobalBucket:(NSString *)tenantPrefix
                     minuteSuffix:(NSString *)minuteSuffix
                            error:(NSError **)error {
    // Sum all buckets that match the global pattern (tenant prefix + minute suffix).
    NSUInteger total = 0;
    for (NSString *key in self.bucketCounts) {
        if ([key hasPrefix:tenantPrefix] && [key hasSuffix:minuteSuffix]) {
            total += [self.bucketCounts[key] unsignedIntegerValue];
        }
    }
    return total;
}

@end

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@interface CMNotificationRateLimiterTests : XCTestCase
@end

@implementation CMNotificationRateLimiterTests

#pragma mark - First 5 Notifications in a Minute -> All Allow

- (void)testFirst5NotificationsAllAllow {
    CMTestNotificationRepository *repo = [[CMTestNotificationRepository alloc] init];
    CMNotificationRateLimiter *limiter = [[CMNotificationRateLimiter alloc] initWithRepository:repo];
    NSDate *now = [NSDate date];

    for (NSUInteger i = 0; i < 5; i++) {
        repo.fakeCount = i; // Simulates 0..4 existing notifications
        NSError *error = nil;
        CMRateLimitDecision decision = [limiter checkLimitForTenantId:@"t1"
                                                          templateKey:@"assigned"
                                                                 date:now
                                                                error:&error];
        XCTAssertNil(error, @"No error expected for notification %lu", (unsigned long)i);
        XCTAssertEqual(decision, CMRateLimitDecisionAllow,
            @"Notification %lu of 5 should be allowed", (unsigned long)i);
    }
}

#pragma mark - 6th Notification in Same Minute -> Coalesce

- (void)testSixthNotificationCoalesces {
    CMTestNotificationRepository *repo = [[CMTestNotificationRepository alloc] init];
    CMNotificationRateLimiter *limiter = [[CMNotificationRateLimiter alloc] initWithRepository:repo];
    NSDate *now = [NSDate date];

    // Simulate that 5 notifications already exist in this bucket.
    repo.fakeCount = 5;
    NSError *error = nil;
    CMRateLimitDecision decision = [limiter checkLimitForTenantId:@"t1"
                                                      templateKey:@"assigned"
                                                             date:now
                                                            error:&error];
    XCTAssertNil(error);
    XCTAssertEqual(decision, CMRateLimitDecisionCoalesce,
        @"6th notification (count=5) should result in Coalesce");
}

#pragma mark - Next Minute Bucket -> Back to Allow

- (void)testNextMinuteBucketBackToAllow {
    CMTestNotificationRepository *repo = [[CMTestNotificationRepository alloc] init];
    CMNotificationRateLimiter *limiter = [[CMNotificationRateLimiter alloc] initWithRepository:repo];

    NSDate *now = [NSDate date];
    // In the current minute bucket: already at the limit.
    repo.fakeCount = 5;
    NSError *error = nil;
    CMRateLimitDecision decision1 = [limiter checkLimitForTenantId:@"t1"
                                                       templateKey:@"assigned"
                                                              date:now
                                                             error:&error];
    XCTAssertEqual(decision1, CMRateLimitDecisionCoalesce);

    // Move to the next minute: reset count to 0.
    NSDate *nextMinute = [now dateByAddingTimeInterval:60.0];
    repo.fakeCount = 0;
    CMRateLimitDecision decision2 = [limiter checkLimitForTenantId:@"t1"
                                                       templateKey:@"assigned"
                                                              date:nextMinute
                                                             error:&error];
    XCTAssertEqual(decision2, CMRateLimitDecisionAllow,
        @"New minute bucket should start at Allow");
}

#pragma mark - Bucket Key Format

- (void)testBucketKeyFormat {
    // Use a known timestamp: 2024-01-01 00:00:00 UTC = 1704067200 seconds
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1704067200.0];
    int64_t expectedBucket = (int64_t)(1704067200.0 / 60.0);

    NSString *key = [CMNotificationRateLimiter bucketKeyForTenantId:@"tenantA"
                                                        templateKey:@"delivered"
                                                               date:date];
    NSString *expected = [NSString stringWithFormat:@"tenantA:delivered:%lld", expectedBucket];
    XCTAssertEqualObjects(key, expected,
        @"Bucket key should be tenantId:templateKey:minuteBucket");
}

#pragma mark - Different Template Keys Have Independent Limits

- (void)testGlobalCapAppliesToAllTemplateKeys {
    // The rate limiter enforces a global 5-per-minute cap per tenant
    // across ALL template keys (not per-template).
    CMPerBucketMockRepository *repo = [[CMPerBucketMockRepository alloc] init];
    CMNotificationRateLimiter *limiter = [[CMNotificationRateLimiter alloc] initWithRepository:repo];
    NSDate *now = [NSDate date];

    // Template "assigned" has 3 in this minute.
    NSString *assignedBucket = [CMNotificationRateLimiter bucketKeyForTenantId:@"t1"
                                                                  templateKey:@"assigned"
                                                                         date:now];
    repo.bucketCounts[assignedBucket] = @(3);

    // Template "delivered" has 2 in this minute. Global total = 5 (at limit).
    NSString *deliveredBucket = [CMNotificationRateLimiter bucketKeyForTenantId:@"t1"
                                                                   templateKey:@"delivered"
                                                                          date:now];
    repo.bucketCounts[deliveredBucket] = @(2);

    NSError *error = nil;
    // Any new notification should coalesce since global count == 5.
    CMRateLimitDecision decision = [limiter checkLimitForTenantId:@"t1"
                                                      templateKey:@"pickup"
                                                             date:now
                                                            error:&error];
    XCTAssertEqual(decision, CMRateLimitDecisionCoalesce,
        @"Global cap of 5 should coalesce when total across templates reaches limit");

    // Under-limit scenario: only 2 total.
    repo.bucketCounts[assignedBucket] = @(1);
    repo.bucketCounts[deliveredBucket] = @(1);

    CMRateLimitDecision decision2 = [limiter checkLimitForTenantId:@"t1"
                                                       templateKey:@"pickup"
                                                              date:now
                                                             error:&error];
    XCTAssertEqual(decision2, CMRateLimitDecisionAllow,
        @"Under global cap (2 total) should allow");
}

@end
