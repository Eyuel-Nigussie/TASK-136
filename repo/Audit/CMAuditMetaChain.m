//
//  CMAuditMetaChain.m
//  CourierMatch
//

#import "CMAuditMetaChain.h"
#import "CMAuditHashChain.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import <CommonCrypto/CommonHMAC.h>

static NSString * const kMetaChainFileName = @"audit-meta-chain.plist";

#pragma mark - CMAuditMetaEntry

@interface CMAuditMetaEntry ()
@property (nonatomic, copy, readwrite)           NSString *tenantId;
@property (nonatomic, copy, readwrite)           NSData   *newHead;
@property (nonatomic, copy, readwrite)           NSString *actorUserId;
@property (nonatomic, copy, readwrite)           NSDate   *timestamp;
@property (nonatomic, copy, readwrite, nullable) NSData   *prevHash;
@property (nonatomic, copy, readwrite)           NSData   *entryHash;
@end

@implementation CMAuditMetaEntry

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithTenantId:(NSString *)tenantId
                         newHead:(NSData *)newHead
                     actorUserId:(NSString *)actorUserId
                       timestamp:(NSDate *)timestamp
                        prevHash:(NSData *)prevHash
                       entryHash:(NSData *)entryHash {
    if ((self = [super init])) {
        _tenantId    = [tenantId copy];
        _newHead     = [newHead copy];
        _actorUserId = [actorUserId copy];
        _timestamp   = [timestamp copy];
        _prevHash    = [prevHash copy];
        _entryHash   = [entryHash copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_tenantId    forKey:@"tenantId"];
    [coder encodeObject:_newHead     forKey:@"newHead"];
    [coder encodeObject:_actorUserId forKey:@"actorUserId"];
    [coder encodeObject:_timestamp   forKey:@"timestamp"];
    [coder encodeObject:_prevHash    forKey:@"prevHash"];
    [coder encodeObject:_entryHash   forKey:@"entryHash"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _tenantId    = [coder decodeObjectOfClass:[NSString class] forKey:@"tenantId"];
        _newHead     = [coder decodeObjectOfClass:[NSData class]   forKey:@"newHead"];
        _actorUserId = [coder decodeObjectOfClass:[NSString class] forKey:@"actorUserId"];
        _timestamp   = [coder decodeObjectOfClass:[NSDate class]   forKey:@"timestamp"];
        _prevHash    = [coder decodeObjectOfClass:[NSData class]   forKey:@"prevHash"];
        _entryHash   = [coder decodeObjectOfClass:[NSData class]   forKey:@"entryHash"];
    }
    return self;
}

@end


#pragma mark - CMAuditMetaChain

@interface CMAuditMetaChain ()
@property (nonatomic, strong) NSMutableArray<CMAuditMetaEntry *> *entries;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy)   NSURL *storageURL;
@end

@implementation CMAuditMetaChain

+ (instancetype)shared {
    static CMAuditMetaChain *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[CMAuditMetaChain alloc] initPrivate]; });
    return s;
}

- (instancetype)initPrivate {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.eaglepoint.couriermatch.metachain",
                                       DISPATCH_QUEUE_SERIAL);
        _storageURL = [self metaChainFileURL];
        _entries = [self loadEntriesFromDisk];
    }
    return self;
}

#pragma mark - Storage Path

- (NSURL *)metaChainFileURL {
    NSURL *appSupport = [[NSFileManager defaultManager]
                         URLForDirectory:NSApplicationSupportDirectory
                         inDomain:NSUserDomainMask
                         appropriateForURL:nil
                         create:YES
                         error:NULL];
    return [appSupport URLByAppendingPathComponent:kMetaChainFileName];
}

#pragma mark - Persistence

- (NSMutableArray<CMAuditMetaEntry *> *)loadEntriesFromDisk {
    NSData *data = [NSData dataWithContentsOfURL:self.storageURL];
    if (!data) {
        return [NSMutableArray array];
    }
    NSSet *classes = [NSSet setWithObjects:[NSMutableArray class],
                      [CMAuditMetaEntry class], nil];
    NSError *err = nil;
    NSMutableArray *loaded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                fromData:data
                                                                   error:&err];
    if (!loaded) {
        CMLogError(@"audit.meta", @"failed to load meta-chain from disk: %@", err);
        return [NSMutableArray array];
    }
    return [loaded mutableCopy];
}

- (void)saveToDisk {
    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.entries
                                         requiringSecureCoding:YES
                                                         error:&err];
    if (!data) {
        CMLogError(@"audit.meta", @"failed to archive meta-chain: %@", err);
        return;
    }
    if (![data writeToURL:self.storageURL options:NSDataWritingAtomic error:&err]) {
        CMLogError(@"audit.meta", @"failed to write meta-chain to disk: %@", err);
    }
}

#pragma mark - Public API

- (BOOL)recordHeadChangeForTenant:(NSString *)tenantId
                          newHead:(NSData *)newHead
                      actorUserId:(NSString *)actorUserId
                            error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *innerError = nil;

    dispatch_sync(self.queue, ^{
        // Get meta seed.
        NSData *metaSeed = [CMAuditHashChain ensureMetaSeed:&innerError];
        if (!metaSeed) {
            return;
        }

        // Previous hash from the last entry in the meta-chain.
        NSData *prevHash = self.entries.lastObject.entryHash;
        NSDate *timestamp = [NSDate date];

        // Compute hash: HMAC-SHA256(metaSeed, prevHash || canonicalJSON(metaFields))
        NSData *entryHash = [self computeMetaHashForTenantId:tenantId
                                                     newHead:newHead
                                                 actorUserId:actorUserId
                                                   timestamp:timestamp
                                                    prevHash:prevHash
                                                    metaSeed:metaSeed];

        CMAuditMetaEntry *entry = [[CMAuditMetaEntry alloc] initWithTenantId:tenantId
                                                                     newHead:newHead
                                                                 actorUserId:actorUserId
                                                                   timestamp:timestamp
                                                                    prevHash:prevHash
                                                                   entryHash:entryHash];
        [self.entries addObject:entry];
        [self saveToDisk];
        success = YES;
        CMLogInfo(@"audit.meta", @"recorded head change for tenant %@", tenantId);
    });

    if (!success && error) {
        *error = innerError ?: [CMError errorWithCode:CMErrorCodeAuditWriteFailed
                                              message:@"Failed to record meta-chain entry"];
    }
    return success;
}

- (NSArray<CMAuditMetaEntry *> *)allEntries {
    __block NSArray *snapshot = nil;
    dispatch_sync(self.queue, ^{
        snapshot = [self.entries copy];
    });
    return snapshot;
}

- (BOOL)verifyChain:(NSError **)error {
    __block BOOL valid = YES;
    __block NSError *innerError = nil;

    dispatch_sync(self.queue, ^{
        NSError *seedErr = nil;
        NSData *metaSeed = [CMAuditHashChain ensureMetaSeed:&seedErr];
        if (!metaSeed) {
            innerError = seedErr;
            valid = NO;
            return;
        }

        NSData *expectedPrevHash = nil;
        for (CMAuditMetaEntry *entry in self.entries) {
            // Verify prevHash linkage.
            if (![self data:entry.prevHash isEqualToData:expectedPrevHash]) {
                innerError = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                            message:@"Meta-chain prevHash mismatch"];
                valid = NO;
                return;
            }

            // Recompute hash and compare.
            NSData *computed = [self computeMetaHashForTenantId:entry.tenantId
                                                       newHead:entry.newHead
                                                   actorUserId:entry.actorUserId
                                                     timestamp:entry.timestamp
                                                      prevHash:entry.prevHash
                                                      metaSeed:metaSeed];
            if (![computed isEqualToData:entry.entryHash]) {
                innerError = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                            message:@"Meta-chain entryHash mismatch"];
                valid = NO;
                return;
            }

            expectedPrevHash = entry.entryHash;
        }
    });

    if (!valid && error) {
        *error = innerError;
    }
    return valid;
}

- (CMAuditMetaEntry *)latestEntryForTenant:(NSString *)tenantId {
    __block CMAuditMetaEntry *result = nil;
    dispatch_sync(self.queue, ^{
        // Walk backwards to find the most recent entry for this tenant.
        for (NSInteger i = (NSInteger)self.entries.count - 1; i >= 0; i--) {
            CMAuditMetaEntry *e = self.entries[(NSUInteger)i];
            if ([e.tenantId isEqualToString:tenantId]) {
                result = e;
                break;
            }
        }
    });
    return result;
}

#pragma mark - Internal Hash Computation

- (NSData *)computeMetaHashForTenantId:(NSString *)tenantId
                               newHead:(NSData *)newHead
                           actorUserId:(NSString *)actorUserId
                             timestamp:(NSDate *)timestamp
                              prevHash:(NSData *)prevHash
                              metaSeed:(NSData *)metaSeed {
    // Build canonical JSON of meta entry fields with sorted keys.
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (tenantId)    dict[@"tenantId"]    = tenantId;
    if (newHead)     dict[@"newHead"]     = [newHead base64EncodedStringWithOptions:0];
    if (actorUserId) dict[@"actorUserId"] = actorUserId;
    if (timestamp)   dict[@"timestamp"]   = [self iso8601StringForDate:timestamp];

    NSData *canonical = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingSortedKeys
                                                         error:NULL];
    if (!canonical) {
        canonical = [NSData data];
    }

    // message = prevHash || canonicalJSON
    NSMutableData *message = [NSMutableData data];
    if (prevHash) {
        [message appendData:prevHash];
    }
    [message appendData:canonical];

    // HMAC-SHA256(metaSeed, message)
    NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           metaSeed.bytes, metaSeed.length,
           message.bytes, message.length,
           hmac.mutableBytes);

    return [hmac copy];
}

- (NSString *)iso8601StringForDate:(NSDate *)date {
    static NSString * const kFormatterKey = @"CMAuditMetaChain.iso8601Formatter";
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

- (BOOL)data:(NSData *)a isEqualToData:(NSData *)b {
    if (a == nil && b == nil) return YES;
    if (a == nil || b == nil) return NO;
    return [a isEqualToData:b];
}

@end
