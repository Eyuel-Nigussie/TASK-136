//
//  CMDateFormatters.m
//  CourierMatch
//

#import "CMDateFormatters.h"

@implementation CMDateFormatters

+ (NSDateFormatter *)baseFormatter {
    NSDateFormatter *f = [NSDateFormatter new];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    return f;
}

+ (NSDateFormatter *)canonicalDateFormatterInTimeZone:(NSTimeZone *)tz {
    NSDateFormatter *f = [self baseFormatter];
    f.dateFormat = @"MM/dd/yyyy";
    f.timeZone = tz ?: [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return f;
}

+ (NSDateFormatter *)canonicalTimeFormatterInTimeZone:(NSTimeZone *)tz {
    NSDateFormatter *f = [self baseFormatter];
    f.dateFormat = @"h:mm a";
    f.timeZone = tz ?: [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return f;
}

+ (NSDateFormatter *)iso8601UTCFormatter {
    NSDateFormatter *f = [self baseFormatter];
    f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    f.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return f;
}

@end
