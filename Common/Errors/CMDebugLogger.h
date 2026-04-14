//
//  CMDebugLogger.h
//  CourierMatch
//
//  Ring-buffered, PII-free debug log persisted under Caches/debug-log.
//  See design.md §16. Safe to call from any thread.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMLogLevel) {
    CMLogLevelDebug = 0,
    CMLogLevelInfo  = 1,
    CMLogLevelWarn  = 2,
    CMLogLevelError = 3,
};

@interface CMDebugLogger : NSObject

+ (instancetype)shared;

/// Append one line. `message` MUST NOT contain PII — callers are responsible.
- (void)log:(CMLogLevel)level
       tag:(NSString *)tag
   message:(NSString *)message;

- (NSArray<NSString *> *)currentBufferSnapshot;
- (void)flushToDisk;

/// Returns a redacted version of a sensitive identifier for safe logging.
/// For strings longer than 12 characters: first 4 chars + "..." + last 4 chars.
/// For shorter strings: "***".
+ (NSString *)redact:(NSString *)value;

@end

#define CMLogInfo(_cmtag, fmt, ...)  [[CMDebugLogger shared] log:CMLogLevelInfo  tag:(_cmtag) message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define CMLogWarn(_cmtag, fmt, ...)  [[CMDebugLogger shared] log:CMLogLevelWarn  tag:(_cmtag) message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define CMLogError(_cmtag, fmt, ...) [[CMDebugLogger shared] log:CMLogLevelError tag:(_cmtag) message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]
#define CMLogDebug(_cmtag, fmt, ...) [[CMDebugLogger shared] log:CMLogLevelDebug tag:(_cmtag) message:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]

NS_ASSUME_NONNULL_END
