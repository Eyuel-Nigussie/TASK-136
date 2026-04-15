//
//  CMDebugLoggerTests.m
//  CourierMatch Unit Tests
//
//  Covers CMDebugLogger: singleton, labelForLevel (all 4 levels),
//  log/buffer/snapshot, nil-safety, redact (nil/short/long/boundary),
//  sanitized export UUID/email redaction, and flushToDisk.
//

#import <XCTest/XCTest.h>
#import "CMDebugLogger.h"

@interface CMDebugLoggerTests : XCTestCase
@end

@implementation CMDebugLoggerTests

#pragma mark - Singleton

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMDebugLogger shared], [CMDebugLogger shared],
                   @"shared must return the same instance on every call");
}

- (void)testSharedIsNotNil {
    XCTAssertNotNil([CMDebugLogger shared]);
}

#pragma mark - labelForLevel:

- (void)testLabelForLevel_Debug {
    XCTAssertEqualObjects([[CMDebugLogger shared] labelForLevel:CMLogLevelDebug], @"DBG");
}

- (void)testLabelForLevel_Info {
    XCTAssertEqualObjects([[CMDebugLogger shared] labelForLevel:CMLogLevelInfo], @"INF");
}

- (void)testLabelForLevel_Warn {
    XCTAssertEqualObjects([[CMDebugLogger shared] labelForLevel:CMLogLevelWarn], @"WRN");
}

- (void)testLabelForLevel_Error {
    XCTAssertEqualObjects([[CMDebugLogger shared] labelForLevel:CMLogLevelError], @"ERR");
}

#pragma mark - log:tag:message: + currentBufferSnapshot

- (void)testCurrentBufferSnapshotIsNotNil {
    XCTAssertNotNil([[CMDebugLogger shared] currentBufferSnapshot]);
}

- (void)testCurrentBufferSnapshotIsArray {
    XCTAssertTrue([[[CMDebugLogger shared] currentBufferSnapshot]
                   isKindOfClass:[NSArray class]]);
}

- (void)testLogAppendsOneEntry {
    NSUInteger before = [[CMDebugLogger shared] currentBufferSnapshot].count;
    [[CMDebugLogger shared] log:CMLogLevelInfo tag:@"APPENDTEST" message:@"append check"];
    NSUInteger after = [[CMDebugLogger shared] currentBufferSnapshot].count;
    XCTAssertEqual(after, before + 1,
                   @"One log call must add exactly one entry to the buffer");
}

- (void)testLogEntryContainsTag {
    [[CMDebugLogger shared] log:CMLogLevelDebug tag:@"MY_UNIQUE_TAG" message:@"tag presence"];
    NSArray<NSString *> *snap = [[CMDebugLogger shared] currentBufferSnapshot];
    XCTAssertTrue([snap.lastObject containsString:@"MY_UNIQUE_TAG"],
                  @"Log entry must contain the tag string");
}

- (void)testLogEntryContainsMessage {
    NSString *msg = [NSString stringWithFormat:@"MSGTOKEN_%lu",
                     (unsigned long)[[NSDate date] timeIntervalSince1970]];
    [[CMDebugLogger shared] log:CMLogLevelInfo tag:@"MSGTEST" message:msg];
    NSArray<NSString *> *snap = [[CMDebugLogger shared] currentBufferSnapshot];
    XCTAssertTrue([snap.lastObject containsString:msg],
                  @"Log entry must contain the message string");
}

- (void)testLogEntryContainsLevelLabel_Error {
    [[CMDebugLogger shared] log:CMLogLevelError tag:@"LBLTEST" message:@"level label"];
    NSArray<NSString *> *snap = [[CMDebugLogger shared] currentBufferSnapshot];
    XCTAssertTrue([snap.lastObject containsString:@"ERR"],
                  @"Error-level entry must contain the 'ERR' label");
}

- (void)testLogEntryContainsLevelLabel_Warn {
    [[CMDebugLogger shared] log:CMLogLevelWarn tag:@"LBLTEST" message:@"warn label"];
    NSArray<NSString *> *snap = [[CMDebugLogger shared] currentBufferSnapshot];
    XCTAssertTrue([snap.lastObject containsString:@"WRN"]);
}

- (void)testLogNilTag_UsesDash {
    [[CMDebugLogger shared] log:CMLogLevelWarn tag:nil message:@"nil tag sentinel"];
    NSArray<NSString *> *snap = [[CMDebugLogger shared] currentBufferSnapshot];
    // Format: "stamp WRN [-] nil tag sentinel"
    XCTAssertTrue([snap.lastObject containsString:@"[-]"],
                  @"Nil tag must be represented as '-' in the log entry");
}

- (void)testLogNilMessage_DoesNotCrash {
    XCTAssertNoThrow([[CMDebugLogger shared] log:CMLogLevelDebug tag:@"NILMSG" message:nil]);
    XCTAssertNotNil([[CMDebugLogger shared] currentBufferSnapshot].lastObject);
}

- (void)testMultipleLogsIncrementCountCorrectly {
    NSUInteger before = [[CMDebugLogger shared] currentBufferSnapshot].count;
    [[CMDebugLogger shared] log:CMLogLevelDebug tag:@"MULTI" message:@"entry 1"];
    [[CMDebugLogger shared] log:CMLogLevelInfo  tag:@"MULTI" message:@"entry 2"];
    [[CMDebugLogger shared] log:CMLogLevelError tag:@"MULTI" message:@"entry 3"];
    NSUInteger after = [[CMDebugLogger shared] currentBufferSnapshot].count;
    XCTAssertEqual(after, before + 3, @"Three log calls must add exactly three entries");
}

#pragma mark - redact:

- (void)testRedactNil_ReturnsMask {
    XCTAssertEqualObjects([CMDebugLogger redact:nil], @"***");
}

- (void)testRedactEmptyString_ReturnsMask {
    XCTAssertEqualObjects([CMDebugLogger redact:@""], @"***");
}

- (void)testRedactShortString_ReturnsMask {
    XCTAssertEqualObjects([CMDebugLogger redact:@"abc"], @"***");
    XCTAssertEqualObjects([CMDebugLogger redact:@"short"], @"***");
}

- (void)testRedact12Chars_ReturnsMask {
    // Exactly 12 chars is NOT > 12, so returns "***"
    XCTAssertEqualObjects([CMDebugLogger redact:@"123456789012"], @"***",
                          @"12-char string must return mask (not > 12)");
}

- (void)testRedactLongString_ReturnsPartialMask {
    // > 12 chars: first 4 + "..." + last 4
    NSString *input  = @"1234567890ABCDE"; // 15 chars
    NSString *result = [CMDebugLogger redact:input];
    XCTAssertEqualObjects(result, @"1234...BCDE");
}

- (void)testRedactBoundary13Chars {
    // 13 chars: just over the threshold
    NSString *input  = @"ABCDEFGHIabcd"; // A B C D E F G H I a b c d = 13
    NSString *result = [CMDebugLogger redact:input];
    XCTAssertEqualObjects(result, @"ABCD...abcd");
}

- (void)testRedactLongUUID_ReturnsPartialMask {
    // UUIDs are 36 chars (including hyphens), well above the 12-char threshold
    NSString *uuid = @"550E8400-E29B-41D4-A716-446655440000";
    NSString *result = [CMDebugLogger redact:uuid];
    XCTAssertEqualObjects(result, @"550E...0000");
}

#pragma mark - sanitizedBufferSnapshotForExport

- (void)testSanitizedSnapshotIsNotNil {
    XCTAssertNotNil([[CMDebugLogger shared] sanitizedBufferSnapshotForExport]);
}

- (void)testSanitizedSnapshotCountMatchesBuffer {
    // sanitized snapshot should have the same number of entries as the raw buffer
    NSUInteger rawCount = [[CMDebugLogger shared] currentBufferSnapshot].count;
    NSUInteger sanitizedCount = [[CMDebugLogger shared] sanitizedBufferSnapshotForExport].count;
    XCTAssertEqual(rawCount, sanitizedCount,
                   @"Sanitized snapshot must have the same entry count as the raw buffer");
}

- (void)testSanitizedSnapshot_RedactsUUID {
    NSString *uuid = @"A1B2C3D4-E5F6-7890-ABCD-EF1234567890";
    [[CMDebugLogger shared] log:CMLogLevelInfo tag:@"UUIDTEST" message:uuid];
    // dispatch_sync in currentBufferSnapshot drains the serial queue (ensures log landed)
    NSArray<NSString *> *sanitized = [[CMDebugLogger shared] sanitizedBufferSnapshotForExport];
    NSString *last = sanitized.lastObject;
    XCTAssertNotNil(last);
    XCTAssertFalse([last containsString:uuid],
                   @"UUID must be removed from sanitized export");
    XCTAssertTrue([last containsString:@"<ID-REDACTED>"],
                  @"UUID must be replaced with <ID-REDACTED>");
}

- (void)testSanitizedSnapshot_RedactsEmail {
    [[CMDebugLogger shared] log:CMLogLevelWarn tag:@"EMAILTEST" message:@"contact user@example.org now"];
    NSArray<NSString *> *sanitized = [[CMDebugLogger shared] sanitizedBufferSnapshotForExport];
    // Find the entry bearing our tag (EMAILTEST has no redactable patterns)
    NSString *entry = nil;
    for (NSString *line in sanitized) {
        if ([line containsString:@"[EMAILTEST]"]) {
            entry = line;
            break;
        }
    }
    if (entry) {
        XCTAssertFalse([entry containsString:@"user@example.org"],
                       @"Email address must be redacted from sanitized export");
        XCTAssertTrue([entry containsString:@"<EMAIL-REDACTED>"],
                      @"Email must be replaced with <EMAIL-REDACTED>");
    }
}

#pragma mark - flushToDisk

- (void)testFlushToDiskDoesNotCrash {
    XCTAssertNoThrow([[CMDebugLogger shared] flushToDisk]);
}

@end
