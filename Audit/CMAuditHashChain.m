//
//  CMAuditHashChain.m
//  CourierMatch
//

#import "CMAuditHashChain.h"
#import "CMAuditEntry.h"
#import "CMKeychain.h"
#import "CMKeychainKeys.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import <CommonCrypto/CommonHMAC.h>

static NSUInteger const kSeedLength = 32; // 256-bit seeds

@implementation CMAuditHashChain

#pragma mark - Canonical JSON

+ (NSData *)canonicalJSONForEntry:(CMAuditEntry *)entry {
    // Build a dictionary of all auditable fields with stable string representations.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // Required fields — always present.
    if (entry.entryId)      dict[@"entryId"]      = entry.entryId;
    if (entry.tenantId)     dict[@"tenantId"]     = entry.tenantId;
    if (entry.actorUserId)  dict[@"actorUserId"]  = entry.actorUserId;
    if (entry.actorRole)    dict[@"actorRole"]    = entry.actorRole;
    if (entry.action)       dict[@"action"]       = entry.action;

    // Optional string fields — include only if non-nil.
    if (entry.targetType)   dict[@"targetType"]   = entry.targetType;
    if (entry.targetId)     dict[@"targetId"]     = entry.targetId;
    if (entry.reason)       dict[@"reason"]       = entry.reason;

    // Optional dictionary fields — serialize deterministically.
    if (entry.beforeJSON)   dict[@"beforeJSON"]   = [self sortedCopyOfObject:entry.beforeJSON];
    if (entry.afterJSON)    dict[@"afterJSON"]    = [self sortedCopyOfObject:entry.afterJSON];

    // Timestamp as ISO 8601 in UTC with millisecond precision.
    if (entry.createdAt)    dict[@"createdAt"]    = [self iso8601StringForDate:entry.createdAt];

    // Sort keys alphabetically and serialize.
    return [self deterministicJSONFromDictionary:dict];
}

/// Recursively sorts dictionary keys. Arrays preserve order, but any dictionaries
/// nested inside them have their keys sorted as well.
+ (id)sortedCopyOfObject:(id)obj {
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSDictionary *d = (NSDictionary *)obj;
        NSMutableDictionary *sorted = [NSMutableDictionary dictionaryWithCapacity:d.count];
        for (id key in d) {
            sorted[key] = [self sortedCopyOfObject:d[key]];
        }
        return sorted;
    }
    if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:[(NSArray *)obj count]];
        for (id item in (NSArray *)obj) {
            [arr addObject:[self sortedCopyOfObject:item]];
        }
        return arr;
    }
    return obj;
}

+ (NSData *)deterministicJSONFromDictionary:(NSDictionary *)dict {
    // NSJSONSerialization with NSJSONWritingSortedKeys produces deterministic output
    // with keys sorted alphabetically and no extra whitespace.
    NSJSONWritingOptions options = NSJSONWritingSortedKeys;
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:options error:&err];
    if (!data) {
        CMLogError(@"audit.hash", @"canonical JSON serialization failed: %@", err);
        return [NSData data];
    }
    return data;
}

+ (NSString *)iso8601StringForDate:(NSDate *)date {
    // Use a thread-local formatter for performance.
    static NSString * const kFormatterKey = @"CMAuditHashChain.iso8601Formatter";
    NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *fmt = threadDict[kFormatterKey];
    if (!fmt) {
        fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        fmt.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        threadDict[kFormatterKey] = fmt;
    }
    return [fmt stringFromDate:date];
}

#pragma mark - HMAC-SHA256 Hash Computation

+ (NSData *)computeHashForEntry:(CMAuditEntry *)entry
                       prevHash:(NSData *)prevHash
                     tenantSeed:(NSData *)tenantSeed {
    NSData *canonical = [self canonicalJSONForEntry:entry];

    // message = prevHash || canonicalJSON
    NSMutableData *message = [NSMutableData data];
    if (prevHash) {
        [message appendData:prevHash];
    }
    [message appendData:canonical];

    // HMAC-SHA256(tenantSeed, message)
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           tenantSeed.bytes, tenantSeed.length,
           message.bytes, message.length,
           hmac.mutableBytes);

    return [hmac copy];
}

#pragma mark - Seed Management

+ (NSData *)ensureSeedForTenant:(NSString *)tenantId error:(NSError **)error {
    if (!tenantId.length) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAuditSeedMissing
                                    message:@"Cannot ensure audit seed: tenantId is empty"];
        }
        return nil;
    }
    NSString *key = [CMKeychainKey_AuditSeedPrefix stringByAppendingString:tenantId];
    NSData *seed = [CMKeychain ensureRandomBytesForKey:key length:kSeedLength error:error];
    if (!seed) {
        CMLogError(@"audit.hash", @"failed to ensure seed for tenant %@", tenantId);
        if (error && !*error) {
            *error = [CMError errorWithCode:CMErrorCodeAuditSeedMissing
                                    message:@"Could not create or retrieve audit seed"];
        }
    }
    return seed;
}

+ (NSData *)ensureMetaSeed:(NSError **)error {
    NSData *seed = [CMKeychain ensureRandomBytesForKey:CMKeychainKey_AuditMetaSeed
                                               length:kSeedLength
                                                error:error];
    if (!seed) {
        CMLogError(@"audit.hash", @"failed to ensure meta-chain seed");
        if (error && !*error) {
            *error = [CMError errorWithCode:CMErrorCodeAuditSeedMissing
                                    message:@"Could not create or retrieve meta-chain seed"];
        }
    }
    return seed;
}

@end
