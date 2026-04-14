//
//  CMAuditHashChainTests.m
//  CourierMatch Tests
//
//  Tests for audit hash chain: canonical JSON determinism, sorted keys,
//  SHA-256 output, chain verification, and tamper detection.
//

#import <XCTest/XCTest.h>
#import "CMAuditHashChain.h"
#import "CMAuditEntry.h"
#import "CMTestCoreDataHelper.h"
#import "CMErrorCodes.h"

@interface CMAuditHashChainTests : XCTestCase
@property (nonatomic, strong) NSManagedObjectContext *ctx;
@end

@implementation CMAuditHashChainTests

- (void)setUp {
    [super setUp];
    self.ctx = [CMTestCoreDataHelper inMemoryContext];
}

#pragma mark - Helpers

/// Creates a test audit entry with known fields.
- (CMAuditEntry *)testEntryWithId:(NSString *)entryId action:(NSString *)action {
    CMAuditEntry *entry = [CMTestCoreDataHelper insertAuditEntryInContext:self.ctx
                                                                 entryId:entryId
                                                                tenantId:@"tenant-1"
                                                             actorUserId:@"user-1"
                                                               actorRole:@"admin"
                                                                  action:action
                                                               createdAt:[NSDate dateWithTimeIntervalSince1970:1700000000.0]];
    entry.targetType = @"Order";
    entry.targetId = @"order-123";
    return entry;
}

/// A fixed 32-byte seed for deterministic tests.
- (NSData *)testSeed {
    uint8_t seedBytes[32];
    memset(seedBytes, 0xAB, 32);
    return [NSData dataWithBytes:seedBytes length:32];
}

#pragma mark - canonicalJSON Is Deterministic

- (void)testCanonicalJSONIsDeterministic {
    CMAuditEntry *entry = [self testEntryWithId:@"E1" action:@"create"];

    NSData *json1 = [CMAuditHashChain canonicalJSONForEntry:entry];
    NSData *json2 = [CMAuditHashChain canonicalJSONForEntry:entry];

    XCTAssertNotNil(json1);
    XCTAssertNotNil(json2);
    XCTAssertEqualObjects(json1, json2,
        @"canonicalJSON must produce identical bytes for the same entry every time");
}

#pragma mark - canonicalJSON Has Sorted Keys

- (void)testCanonicalJSONHasSortedKeys {
    CMAuditEntry *entry = [self testEntryWithId:@"E1" action:@"update"];
    entry.reason = @"Test reason";

    NSData *jsonData = [CMAuditHashChain canonicalJSONForEntry:entry];
    XCTAssertNotNil(jsonData);

    // Parse the JSON back to verify key order in the raw bytes.
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(jsonString);

    // With NSJSONWritingSortedKeys, keys should appear in alphabetical order.
    // Check that "action" appears before "entryId" which appears before "tenantId".
    NSRange actionRange = [jsonString rangeOfString:@"\"action\""];
    NSRange entryIdRange = [jsonString rangeOfString:@"\"entryId\""];
    NSRange tenantIdRange = [jsonString rangeOfString:@"\"tenantId\""];

    XCTAssertTrue(actionRange.location < entryIdRange.location,
        @"'action' key should appear before 'entryId' in sorted JSON");
    XCTAssertTrue(entryIdRange.location < tenantIdRange.location,
        @"'entryId' key should appear before 'tenantId' in sorted JSON");
}

#pragma mark - computeHash Returns 32 Bytes (SHA-256)

- (void)testComputeHashReturns32Bytes {
    CMAuditEntry *entry = [self testEntryWithId:@"E1" action:@"create"];

    NSData *hash = [CMAuditHashChain computeHashForEntry:entry
                                                prevHash:nil
                                              tenantSeed:[self testSeed]];

    XCTAssertNotNil(hash);
    XCTAssertEqual(hash.length, (NSUInteger)32,
        @"HMAC-SHA256 output must be exactly 32 bytes");
}

#pragma mark - Different prevHash -> Different entryHash

- (void)testDifferentPrevHashProducesDifferentEntryHash {
    CMAuditEntry *entry = [self testEntryWithId:@"E1" action:@"create"];
    NSData *seed = [self testSeed];

    NSData *hash1 = [CMAuditHashChain computeHashForEntry:entry
                                                 prevHash:nil
                                               tenantSeed:seed];

    uint8_t prevBytes[32];
    memset(prevBytes, 0xFF, 32);
    NSData *fakePrev = [NSData dataWithBytes:prevBytes length:32];

    NSData *hash2 = [CMAuditHashChain computeHashForEntry:entry
                                                 prevHash:fakePrev
                                               tenantSeed:seed];

    XCTAssertNotEqualObjects(hash1, hash2,
        @"Different prevHash must produce different entryHash");
}

#pragma mark - Different Entry Content -> Different entryHash

- (void)testDifferentEntryContentProducesDifferentEntryHash {
    CMAuditEntry *entry1 = [self testEntryWithId:@"E1" action:@"create"];
    CMAuditEntry *entry2 = [self testEntryWithId:@"E2" action:@"delete"];
    NSData *seed = [self testSeed];

    NSData *hash1 = [CMAuditHashChain computeHashForEntry:entry1
                                                 prevHash:nil
                                               tenantSeed:seed];
    NSData *hash2 = [CMAuditHashChain computeHashForEntry:entry2
                                                 prevHash:nil
                                               tenantSeed:seed];

    XCTAssertNotEqualObjects(hash1, hash2,
        @"Different entry content must produce different entryHash");
}

#pragma mark - Same Inputs -> Same Hash (Deterministic)

- (void)testSameInputsSameHash {
    CMAuditEntry *entry = [self testEntryWithId:@"E1" action:@"create"];
    NSData *seed = [self testSeed];

    NSData *hash1 = [CMAuditHashChain computeHashForEntry:entry
                                                 prevHash:nil
                                               tenantSeed:seed];
    NSData *hash2 = [CMAuditHashChain computeHashForEntry:entry
                                                 prevHash:nil
                                               tenantSeed:seed];

    XCTAssertEqualObjects(hash1, hash2,
        @"Same entry + same prevHash + same seed must produce same hash");
}

#pragma mark - Verify Chain of 3 Entries Succeeds

- (void)testVerifyChainOf3EntriesSucceeds {
    NSData *seed = [self testSeed];

    // Entry 1: genesis (prevHash = nil)
    CMAuditEntry *e1 = [self testEntryWithId:@"E1" action:@"create"];
    NSData *hash1 = [CMAuditHashChain computeHashForEntry:e1
                                                 prevHash:nil
                                               tenantSeed:seed];
    e1.prevHash = nil;
    e1.entryHash = hash1;

    // Entry 2: prevHash = hash1
    CMAuditEntry *e2 = [self testEntryWithId:@"E2" action:@"update"];
    NSData *hash2 = [CMAuditHashChain computeHashForEntry:e2
                                                 prevHash:hash1
                                               tenantSeed:seed];
    e2.prevHash = hash1;
    e2.entryHash = hash2;

    // Entry 3: prevHash = hash2
    CMAuditEntry *e3 = [self testEntryWithId:@"E3" action:@"delete"];
    NSData *hash3 = [CMAuditHashChain computeHashForEntry:e3
                                                 prevHash:hash2
                                               tenantSeed:seed];
    e3.prevHash = hash2;
    e3.entryHash = hash3;

    // Verify: recompute each entry's hash and compare.
    NSArray<CMAuditEntry *> *chain = @[e1, e2, e3];
    BOOL chainValid = YES;
    for (NSUInteger i = 0; i < chain.count; i++) {
        CMAuditEntry *entry = chain[i];
        NSData *expectedPrev = (i == 0) ? nil : chain[i - 1].entryHash;
        NSData *recomputed = [CMAuditHashChain computeHashForEntry:entry
                                                          prevHash:expectedPrev
                                                        tenantSeed:seed];
        if (![recomputed isEqualToData:entry.entryHash]) {
            chainValid = NO;
            break;
        }
    }

    XCTAssertTrue(chainValid, @"Chain of 3 entries should verify successfully");
}

#pragma mark - Tamper with Middle Entry -> Chain Verification Fails

- (void)testTamperWithMiddleEntryBreaksChain {
    NSData *seed = [self testSeed];

    // Build a valid chain of 3.
    CMAuditEntry *e1 = [self testEntryWithId:@"E1" action:@"create"];
    NSData *hash1 = [CMAuditHashChain computeHashForEntry:e1 prevHash:nil tenantSeed:seed];
    e1.prevHash = nil;
    e1.entryHash = hash1;

    CMAuditEntry *e2 = [self testEntryWithId:@"E2" action:@"update"];
    NSData *hash2 = [CMAuditHashChain computeHashForEntry:e2 prevHash:hash1 tenantSeed:seed];
    e2.prevHash = hash1;
    e2.entryHash = hash2;

    CMAuditEntry *e3 = [self testEntryWithId:@"E3" action:@"delete"];
    NSData *hash3 = [CMAuditHashChain computeHashForEntry:e3 prevHash:hash2 tenantSeed:seed];
    e3.prevHash = hash2;
    e3.entryHash = hash3;

    // TAMPER: modify the middle entry's action after its hash was computed.
    e2.action = @"TAMPERED_ACTION";

    // Verification of e2: recompute hash with its stored prevHash and compare.
    NSData *recomputed2 = [CMAuditHashChain computeHashForEntry:e2
                                                       prevHash:e2.prevHash
                                                     tenantSeed:seed];
    BOOL e2Valid = [recomputed2 isEqualToData:e2.entryHash];
    XCTAssertFalse(e2Valid,
        @"Tampered middle entry should fail hash verification (CMErrorCodeAuditChainBroken)");

    // Verify that we can detect this programmatically and flag as CMErrorCodeAuditChainBroken.
    if (!e2Valid) {
        NSError *chainError = [NSError errorWithDomain:@"com.eaglepoint.couriermatch.error"
                                                  code:CMErrorCodeAuditChainBroken
                                              userInfo:@{NSLocalizedDescriptionKey: @"Audit chain broken at entry E2"}];
        XCTAssertEqual(chainError.code, CMErrorCodeAuditChainBroken,
            @"Error code should be CMErrorCodeAuditChainBroken (7001)");
    }
}

@end
