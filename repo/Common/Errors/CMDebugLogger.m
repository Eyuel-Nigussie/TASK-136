//
//  CMDebugLogger.m
//  CourierMatch
//

#import "CMDebugLogger.h"
#import "CMFileLocations.h"

static NSUInteger const kRingCapacity = 2048;

@interface CMDebugLogger ()
@property (nonatomic, strong) NSMutableArray<NSString *> *ring;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSDateFormatter *stampFormatter;
@end

@implementation CMDebugLogger

+ (instancetype)shared {
    static CMDebugLogger *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMDebugLogger new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _ring = [NSMutableArray arrayWithCapacity:kRingCapacity];
        _queue = dispatch_queue_create("com.eaglepoint.couriermatch.debuglog", DISPATCH_QUEUE_SERIAL);
        _stampFormatter = [[NSDateFormatter alloc] init];
        _stampFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _stampFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
        _stampFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    }
    return self;
}

- (NSString *)labelForLevel:(CMLogLevel)level {
    switch (level) {
        case CMLogLevelDebug: return @"DBG";
        case CMLogLevelInfo:  return @"INF";
        case CMLogLevelWarn:  return @"WRN";
        case CMLogLevelError: return @"ERR";
    }
    return @"???";
}

- (void)log:(CMLogLevel)level tag:(NSString *)tag message:(NSString *)message {
    NSString *stamp = [self.stampFormatter stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"%@ %@ [%@] %@",
                      stamp, [self labelForLevel:level], tag ?: @"-", message ?: @""];
    dispatch_async(self.queue, ^{
        if (self.ring.count >= kRingCapacity) {
            [self.ring removeObjectAtIndex:0];
        }
        [self.ring addObject:line];
    });
}

- (NSArray<NSString *> *)currentBufferSnapshot {
    __block NSArray *snap = nil;
    dispatch_sync(self.queue, ^{ snap = [self.ring copy]; });
    return snap;
}

- (NSArray<NSString *> *)sanitizedBufferSnapshotForExport {
    NSArray<NSString *> *raw = [self currentBufferSnapshot];
    NSMutableArray<NSString *> *sanitized = [NSMutableArray arrayWithCapacity:raw.count];

    // Patterns to redact: UUIDs, email-like strings, long hex sequences, userId/tenantId values
    static NSRegularExpression *uuidRegex = nil;
    static NSRegularExpression *emailRegex = nil;
    static NSRegularExpression *hexIdRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uuidRegex = [NSRegularExpression regularExpressionWithPattern:
            @"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
            options:0 error:nil];
        emailRegex = [NSRegularExpression regularExpressionWithPattern:
            @"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            options:0 error:nil];
        hexIdRegex = [NSRegularExpression regularExpressionWithPattern:
            @"\\b[0-9a-fA-F]{16,}\\b"
            options:0 error:nil];
    });

    for (NSString *line in raw) {
        NSMutableString *scrubbed = [line mutableCopy];
        NSRange fullRange = NSMakeRange(0, scrubbed.length);

        [uuidRegex replaceMatchesInString:scrubbed options:0 range:fullRange
                             withTemplate:@"<ID-REDACTED>"];
        fullRange = NSMakeRange(0, scrubbed.length);
        [emailRegex replaceMatchesInString:scrubbed options:0 range:fullRange
                              withTemplate:@"<EMAIL-REDACTED>"];
        fullRange = NSMakeRange(0, scrubbed.length);
        [hexIdRegex replaceMatchesInString:scrubbed options:0 range:fullRange
                              withTemplate:@"<HEX-REDACTED>"];

        [sanitized addObject:[scrubbed copy]];
    }

    return [sanitized copy];
}

+ (NSString *)redact:(NSString *)value {
    if (!value) { return @"***"; }
    if (value.length > 12) {
        return [NSString stringWithFormat:@"%@...%@",
                [value substringToIndex:4],
                [value substringFromIndex:value.length - 4]];
    }
    return @"***";
}

- (void)flushToDisk {
    dispatch_async(self.queue, ^{
        NSURL *dir = [CMFileLocations debugLogDirectoryCreatingIfNeeded:YES];
        if (!dir) { return; }
        NSURL *file = [dir URLByAppendingPathComponent:@"log.txt"];
        NSString *blob = [self.ring componentsJoinedByString:@"\n"];
        NSData *data = [blob dataUsingEncoding:NSUTF8StringEncoding];
        [data writeToURL:file
                 options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUnlessOpen
                   error:NULL];
    });
}

@end
