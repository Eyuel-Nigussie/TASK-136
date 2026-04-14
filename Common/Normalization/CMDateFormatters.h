//
//  CMDateFormatters.h
//  CourierMatch
//
//  Canonical formatters per design.md §7.1 and questions.md Q15.
//  All canonical formatters use `en_US_POSIX` and an explicit time zone.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMDateFormatters : NSObject

/// Canonical `MM/dd/yyyy`. Time zone defaults to UTC unless overridden.
+ (NSDateFormatter *)canonicalDateFormatterInTimeZone:(nullable NSTimeZone *)tz;

/// Canonical `h:mm a`.
+ (NSDateFormatter *)canonicalTimeFormatterInTimeZone:(nullable NSTimeZone *)tz;

/// ISO-8601 with ms and `Z` suffix. Used only for audit / logging.
+ (NSDateFormatter *)iso8601UTCFormatter;

@end

NS_ASSUME_NONNULL_END
