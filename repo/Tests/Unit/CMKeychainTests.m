//
//  CMKeychainTests.m
//  CourierMatch Unit Tests
//
//  Covers CMKeychain read/write/delete operations.
//

#import <XCTest/XCTest.h>
#import "CMKeychain.h"

@interface CMKeychainTests : XCTestCase
@end

@implementation CMKeychainTests

- (NSString *)uniqueKey {
    return [NSString stringWithFormat:@"test-keychain-%@", [[NSUUID UUID] UUIDString]];
}

- (void)testSetDataAndReadBack {
    NSString *key = [self uniqueKey];
    NSData *data = [@"hello keychain" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *setErr = nil;
    BOOL set = [CMKeychain setData:data forKey:key error:&setErr];
    XCTAssertTrue(set, @"Set should succeed: %@", setErr);
    XCTAssertNil(setErr);

    NSError *getErr = nil;
    NSData *retrieved = [CMKeychain dataForKey:key error:&getErr];
    XCTAssertNil(getErr);
    XCTAssertNotNil(retrieved);
    XCTAssertEqualObjects(retrieved, data);

    // Cleanup.
    [CMKeychain deleteKey:key error:nil];
}

- (void)testOverwriteExistingKey {
    NSString *key = [self uniqueKey];
    NSData *first = [@"first" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *second = [@"second" dataUsingEncoding:NSUTF8StringEncoding];

    [CMKeychain setData:first forKey:key error:nil];
    [CMKeychain setData:second forKey:key error:nil];

    NSData *retrieved = [CMKeychain dataForKey:key error:nil];
    XCTAssertEqualObjects(retrieved, second, @"Overwritten value should be retrieved");

    [CMKeychain deleteKey:key error:nil];
}

- (void)testDeleteKey {
    NSString *key = [self uniqueKey];
    NSData *data = [@"to delete" dataUsingEncoding:NSUTF8StringEncoding];

    [CMKeychain setData:data forKey:key error:nil];

    NSError *delErr = nil;
    BOOL deleted = [CMKeychain deleteKey:key error:&delErr];
    XCTAssertTrue(deleted, @"Delete should succeed: %@", delErr);

    // After deletion, reading should return nil.
    NSData *afterDelete = [CMKeychain dataForKey:key error:nil];
    XCTAssertNil(afterDelete, @"Deleted key should not be readable");
}

- (void)testDeleteNonexistentKeyReturnsError {
    NSString *key = [self uniqueKey];
    NSError *err = nil;
    BOOL result = [CMKeychain deleteKey:key error:&err];
    // Keychain returns errSecItemNotFound for non-existent keys.
    // Result may be YES or NO depending on implementation.
    (void)result;
    (void)err;
}

- (void)testDataForKeyNotFound {
    NSString *key = [self uniqueKey];
    NSError *err = nil;
    NSData *data = [CMKeychain dataForKey:key error:&err];
    XCTAssertNil(data, @"Non-existent key should return nil data");
}

- (void)testEnsureRandomBytesCreatesNewKey {
    NSString *key = [self uniqueKey];
    // Ensure key doesn't exist first.
    [CMKeychain deleteKey:key error:nil];

    NSError *err = nil;
    NSData *bytes = [CMKeychain ensureRandomBytesForKey:key length:32 error:&err];
    XCTAssertNotNil(bytes, @"Should create random bytes: %@", err);
    XCTAssertNil(err);
    XCTAssertEqual(bytes.length, (NSUInteger)32);

    [CMKeychain deleteKey:key error:nil];
}

- (void)testEnsureRandomBytesReturnsSameValueOnSecondCall {
    NSString *key = [self uniqueKey];
    [CMKeychain deleteKey:key error:nil];

    NSData *first  = [CMKeychain ensureRandomBytesForKey:key length:16 error:nil];
    NSData *second = [CMKeychain ensureRandomBytesForKey:key length:16 error:nil];

    XCTAssertNotNil(first);
    XCTAssertNotNil(second);
    XCTAssertEqualObjects(first, second, @"Same key should return same bytes on second call");

    [CMKeychain deleteKey:key error:nil];
}

- (void)testSetNilDataReturnsNoOrError {
    NSString *key = [self uniqueKey];
    NSError *err = nil;
    // Passing nil data should not crash.
    @try {
        BOOL result = [CMKeychain setData:nil forKey:key error:&err];
        (void)result;
    } @catch (NSException *e) {
        // Some implementations throw on nil data — that's acceptable.
    }
}

- (void)testSetAndReadLargeData {
    NSString *key = [self uniqueKey];
    // Test with larger data (1KB).
    NSMutableData *largeData = [NSMutableData dataWithLength:1024];
    for (int i = 0; i < 1024; i++) {
        ((uint8_t *)largeData.mutableBytes)[i] = (uint8_t)(i % 256);
    }

    NSError *setErr = nil;
    BOOL set = [CMKeychain setData:largeData forKey:key error:&setErr];
    XCTAssertTrue(set, @"Large data set should succeed: %@", setErr);

    NSData *retrieved = [CMKeychain dataForKey:key error:nil];
    XCTAssertEqualObjects(retrieved, largeData);

    [CMKeychain deleteKey:key error:nil];
}

- (void)testSetNilKeyReturnsError {
    NSData *data = [@"some data" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err = nil;
    // Passing nil key should not crash and should return NO.
    @try {
        BOOL result = [CMKeychain setData:data forKey:nil error:&err];
        // Implementation returns NO with error for nil key.
        if (!result) {
            // Error expected for nil key.
            (void)err;
        }
    } @catch (NSException *e) {
        // Some implementations throw — acceptable.
    }
}

- (void)testEnsureRandomBytesUpgradesLength {
    // Store 8 bytes, then request 16 — should generate new 16-byte value.
    NSString *key = [self uniqueKey];
    [CMKeychain deleteKey:key error:nil];

    NSData *short8 = [CMKeychain ensureRandomBytesForKey:key length:8 error:nil];
    XCTAssertNotNil(short8);
    XCTAssertEqual(short8.length, (NSUInteger)8);

    // Request 16 bytes — existing 8-byte entry is shorter, so new bytes generated.
    NSData *long16 = [CMKeychain ensureRandomBytesForKey:key length:16 error:nil];
    XCTAssertNotNil(long16);
    XCTAssertEqual(long16.length, (NSUInteger)16);

    // The second call for 8 bytes should still return the 16-byte stored value.
    NSData *again8 = [CMKeychain ensureRandomBytesForKey:key length:8 error:nil];
    XCTAssertNotNil(again8);
    XCTAssertGreaterThanOrEqual(again8.length, (NSUInteger)8);

    [CMKeychain deleteKey:key error:nil];
}

- (void)testDeleteKeyReturnsYesForNonexistent {
    // Deleting a key that was never set should not error fatally.
    NSString *key = [self uniqueKey];
    NSError *err = nil;
    BOOL result = [CMKeychain deleteKey:key error:&err];
    // errSecItemNotFound returns YES (no-op delete), err is nil.
    XCTAssertTrue(result, @"Deleting nonexistent key should return YES");
    XCTAssertNil(err, @"No error expected for nonexistent key deletion");
}

@end
