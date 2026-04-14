//
//  CMDateFormattersTests.m
//  CourierMatch
//
//  Unit tests for CMDateFormatters — canonical date/time formatting per S7.1.
//

#import <XCTest/XCTest.h>
#import "CMDateFormatters.h"

@interface CMDateFormattersTests : XCTestCase
@end

@implementation CMDateFormattersTests

#pragma mark - Helpers

/// Returns a known reference date: 2024-07-04 14:30:00 UTC.
- (NSDate *)referenceDate {
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year   = 2024;
    c.month  = 7;
    c.day    = 4;
    c.hour   = 14;
    c.minute = 30;
    c.second = 0;
    c.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    return [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:c];
}

#pragma mark - canonicalDateFormatter

- (void)testCanonicalDateFormatter_FormatsAsMMddyyyy {
    NSDateFormatter *f = [CMDateFormatters canonicalDateFormatterInTimeZone:
                          [NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSString *formatted = [f stringFromDate:[self referenceDate]];
    XCTAssertEqualObjects(formatted, @"07/04/2024");
}

- (void)testCanonicalDateFormatter_RespectsTimeZone {
    // In UTC it is July 4. In Pacific (UTC-7 in summer) at 00:30 UTC it is
    // still July 3 — but our reference date is 14:30 UTC, so Pacific = 07:30,
    // still July 4. Use a date at 01:00 UTC instead.
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year   = 2024;
    c.month  = 7;
    c.day    = 4;
    c.hour   = 1;
    c.minute = 0;
    c.second = 0;
    c.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    NSDate *d = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian] dateFromComponents:c];

    NSDateFormatter *utc = [CMDateFormatters canonicalDateFormatterInTimeZone:
                            [NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSDateFormatter *pacific = [CMDateFormatters canonicalDateFormatterInTimeZone:
                                [NSTimeZone timeZoneWithName:@"America/Los_Angeles"]];

    NSString *utcStr = [utc stringFromDate:d];
    NSString *pacStr = [pacific stringFromDate:d];
    // 01:00 UTC on July 4 is 18:00 PDT on July 3.
    XCTAssertEqualObjects(utcStr, @"07/04/2024");
    XCTAssertEqualObjects(pacStr, @"07/03/2024");
}

- (void)testCanonicalDateFormatter_NilTimeZone_DefaultsToUTC {
    NSDateFormatter *f = [CMDateFormatters canonicalDateFormatterInTimeZone:nil];
    // NSTimeZone may report "GMT" or "UTC" for the same zero-offset zone.
    XCTAssertEqual(f.timeZone.secondsFromGMT, 0,
                   @"Nil time zone should default to UTC (zero offset)");
    NSString *s = [f stringFromDate:[self referenceDate]];
    XCTAssertEqualObjects(s, @"07/04/2024");
}

#pragma mark - canonicalTimeFormatter

- (void)testCanonicalTimeFormatter_FormatsAsHmmA {
    NSDateFormatter *f = [CMDateFormatters canonicalTimeFormatterInTimeZone:
                          [NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    NSString *formatted = [f stringFromDate:[self referenceDate]];
    XCTAssertEqualObjects(formatted, @"2:30 PM");
}

- (void)testCanonicalTimeFormatter_RespectsTimeZone {
    // 14:30 UTC → 9:30 AM in CDT (America/Chicago, UTC-5 in summer).
    NSDateFormatter *f = [CMDateFormatters canonicalTimeFormatterInTimeZone:
                          [NSTimeZone timeZoneWithName:@"America/Chicago"]];
    NSString *formatted = [f stringFromDate:[self referenceDate]];
    XCTAssertEqualObjects(formatted, @"9:30 AM");
}

- (void)testCanonicalTimeFormatter_NilTimeZone_DefaultsToUTC {
    NSDateFormatter *f = [CMDateFormatters canonicalTimeFormatterInTimeZone:nil];
    // NSTimeZone may report "GMT" or "UTC" for the same zero-offset zone.
    XCTAssertEqual(f.timeZone.secondsFromGMT, 0,
                   @"Nil time zone should default to UTC (zero offset)");
}

#pragma mark - iso8601UTCFormatter

- (void)testISO8601UTC_ProducesCorrectFormatWithZSuffix {
    NSDateFormatter *f = [CMDateFormatters iso8601UTCFormatter];
    NSString *formatted = [f stringFromDate:[self referenceDate]];
    // Expected: "2024-07-04T14:30:00.000Z"
    XCTAssertEqualObjects(formatted, @"2024-07-04T14:30:00.000Z");
}

- (void)testISO8601UTC_AlwaysUsesUTC {
    NSDateFormatter *f = [CMDateFormatters iso8601UTCFormatter];
    // NSTimeZone may report "GMT" or "UTC" for the same zero-offset zone.
    XCTAssertEqual(f.timeZone.secondsFromGMT, 0,
                   @"ISO-8601 formatter should use UTC (zero offset)");
}

- (void)testISO8601UTC_Locale_IsPOSIX {
    NSDateFormatter *f = [CMDateFormatters iso8601UTCFormatter];
    XCTAssertEqualObjects(f.locale.localeIdentifier, @"en_US_POSIX");
}

@end
