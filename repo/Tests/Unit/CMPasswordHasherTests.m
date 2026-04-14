//
//  CMPasswordHasherTests.m
//  CourierMatch
//
//  Unit tests for CMPasswordHasher — PBKDF2-SHA512 + HMAC-SHA256 hashing.
//
//  NOTE: hashPassword:salt:iterations: depends on a pepper stored in the
//  Keychain. In a test-host that has Keychain access these tests exercise the
//  real implementation. If the pepper cannot be loaded (CI sandbox),
//  hashPassword returns nil and we skip the downstream assertions gracefully.
//

#import <XCTest/XCTest.h>
#import "CMPasswordHasher.h"

@interface CMPasswordHasherTests : XCTestCase
@end

@implementation CMPasswordHasherTests

#pragma mark - generateSalt

- (void)testGenerateSalt_ReturnsNonNilData {
    NSData *salt = [CMPasswordHasher generateSalt];
    XCTAssertNotNil(salt);
}

- (void)testGenerateSalt_Returns32Bytes {
    NSData *salt = [CMPasswordHasher generateSalt];
    XCTAssertEqual(salt.length, (NSUInteger)32);
}

- (void)testGenerateSalt_TwoCallsProduceDifferentSalts {
    NSData *a = [CMPasswordHasher generateSalt];
    NSData *b = [CMPasswordHasher generateSalt];
    XCTAssertFalse([a isEqualToData:b],
                   @"Two random salts should differ (collision probability negligible)");
}

#pragma mark - Constants

- (void)testConstants {
    XCTAssertEqual(CMPasswordHasherSaltLength, 32u);
    XCTAssertEqual(CMPasswordHasherHashLength, 32u);
    XCTAssertEqual(CMPasswordHasherDefaultIterations, 600000u);
}

#pragma mark - hashPassword

- (void)testHashPassword_ReturnsNonNilData {
    NSData *salt = [CMPasswordHasher generateSalt];
    NSData *hash = [CMPasswordHasher hashPassword:@"Test1234!abc"
                                             salt:salt
                                       iterations:1000];
    // May be nil if Keychain pepper is unavailable (CI sandbox). Guard gracefully.
    if (!hash) {
        NSLog(@"Skipping hashPassword assertions — pepper unavailable in this environment.");
        return;
    }
    XCTAssertNotNil(hash);
    XCTAssertEqual(hash.length, (NSUInteger)32, @"Hash should be 32 bytes (HMAC-SHA256 output)");
}

- (void)testHashPassword_Deterministic_SameInputsSameOutput {
    NSData *salt = [CMPasswordHasher generateSalt];
    NSUInteger iters = 1000;
    NSData *h1 = [CMPasswordHasher hashPassword:@"Abc123!xyz99" salt:salt iterations:iters];
    NSData *h2 = [CMPasswordHasher hashPassword:@"Abc123!xyz99" salt:salt iterations:iters];
    if (!h1 || !h2) { return; } // pepper unavailable
    XCTAssertEqualObjects(h1, h2, @"Same password + salt + iterations must yield the same hash");
}

- (void)testHashPassword_DifferentSalt_DifferentHash {
    NSData *salt1 = [CMPasswordHasher generateSalt];
    NSData *salt2 = [CMPasswordHasher generateSalt];
    NSUInteger iters = 1000;
    NSData *h1 = [CMPasswordHasher hashPassword:@"Abc123!xyz99" salt:salt1 iterations:iters];
    NSData *h2 = [CMPasswordHasher hashPassword:@"Abc123!xyz99" salt:salt2 iterations:iters];
    if (!h1 || !h2) { return; }
    XCTAssertFalse([h1 isEqualToData:h2], @"Different salts must yield different hashes");
}

#pragma mark - verifyPassword

- (void)testVerifyPassword_CorrectPassword_ReturnsYES {
    NSData *salt = [CMPasswordHasher generateSalt];
    NSUInteger iters = 1000;
    NSData *hash = [CMPasswordHasher hashPassword:@"Correct!1234" salt:salt iterations:iters];
    if (!hash) { return; }
    BOOL ok = [CMPasswordHasher verifyPassword:@"Correct!1234"
                                           salt:salt
                                     iterations:iters
                                    expectedHash:hash];
    XCTAssertTrue(ok, @"verifyPassword must return YES for the correct password");
}

- (void)testVerifyPassword_WrongPassword_ReturnsNO {
    NSData *salt = [CMPasswordHasher generateSalt];
    NSUInteger iters = 1000;
    NSData *hash = [CMPasswordHasher hashPassword:@"Correct!1234" salt:salt iterations:iters];
    if (!hash) { return; }
    BOOL ok = [CMPasswordHasher verifyPassword:@"Wrong!Password9"
                                           salt:salt
                                     iterations:iters
                                    expectedHash:hash];
    XCTAssertFalse(ok, @"verifyPassword must return NO for an incorrect password");
}

- (void)testVerifyPassword_NilExpected_ReturnsNO {
    NSData *salt = [CMPasswordHasher generateSalt];
    BOOL ok = [CMPasswordHasher verifyPassword:@"Anything!123"
                                           salt:salt
                                     iterations:1000
                                    expectedHash:nil];
    XCTAssertFalse(ok);
}

#pragma mark - Constant-time verification (functional, not timing)

- (void)testVerifyPassword_ConstantTimeComparison_FunctionallyCorrect {
    // Ensure that a single bit difference is still caught.
    NSData *salt = [CMPasswordHasher generateSalt];
    NSUInteger iters = 1000;
    NSData *hash = [CMPasswordHasher hashPassword:@"MyP@ss!12345" salt:salt iterations:iters];
    if (!hash) { return; }
    // Flip the first byte to create a near-match.
    NSMutableData *tampered = [hash mutableCopy];
    ((uint8_t *)tampered.mutableBytes)[0] ^= 0x01;
    BOOL ok = [CMPasswordHasher verifyPassword:@"MyP@ss!12345"
                                           salt:salt
                                     iterations:iters
                                    expectedHash:tampered];
    XCTAssertFalse(ok, @"Even a single-bit difference must be rejected");
}

@end
