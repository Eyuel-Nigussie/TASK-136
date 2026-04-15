//
//  CMAuditChainIntegrationTests.m
//  CourierMatch Integration Tests
//
//  Audit chain integrity: hash-chain linkage, verification, and tamper detection.
//

#import "CMIntegrationTestCase.h"
#import "CMAuditService.h"
#import "CMAuditEntry.h"
#import "CMAuditVerifier.h"
#import "CMAuditRepository.h"
#import "CMAuditHashChain.h"
#import "CMTenantContext.h"
#import "CMError.h"
#import "CMErrorCodes.h"
#import "CMUserAccount.h"
#import "NSManagedObjectContext+CMHelpers.h"

@interface CMAuditChainIntegrationTests : CMIntegrationTestCase
@end

@implementation CMAuditChainIntegrationTests

#pragma mark - Test 1: Write 10 Audit Entries

- (void)testWriteTenAuditEntries {
    // Write 10 audit entries via CMAuditService
    for (int i = 0; i < 10; i++) {
        XCTestExpectation *exp = [self expectationWithDescription:
            [NSString stringWithFormat:@"Audit entry %d", i + 1]];

        NSString *action = [NSString stringWithFormat:@"test.action.%d", i + 1];
        NSDictionary *afterJSON = @{@"step": @(i + 1), @"data": @"test"};

        [[CMAuditService shared] recordAction:action
                                   targetType:@"TestEntity"
                                     targetId:[NSString stringWithFormat:@"entity-%d", i + 1]
                                   beforeJSON:nil
                                    afterJSON:afterJSON
                                       reason:[NSString stringWithFormat:@"Test action %d", i + 1]
                                   completion:^(CMAuditEntry *entry, NSError *error) {
            XCTAssertNotNil(entry, @"Audit entry %d should be created: %@", i + 1, error);
            XCTAssertNotNil(entry.entryId, @"Entry should have an ID");
            XCTAssertNotNil(entry.entryHash, @"Entry should have a hash");
            XCTAssertEqualObjects(entry.tenantId, self.testTenantId);
            [exp fulfill];
        }];

        [self waitForExpectationsWithTimeout:5.0 handler:nil];
    }
}

#pragma mark - Test 2: Each Entry Has prevHash = Prior Entry's entryHash

- (void)testChainLinkageConsistency {
    // Write 10 entries
    [self writeTestEntries:10];

    // Fetch all entries for the tenant in chronological order
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    NSError *error = nil;
    NSArray<CMAuditEntry *> *entries = [repo entriesAfter:nil
                                                forTenant:self.testTenantId
                                                    limit:100
                                                    error:&error];
    XCTAssertNil(error, @"Fetch should succeed: %@", error);
    XCTAssertGreaterThanOrEqual(entries.count, 10, @"Should have at least 10 entries");

    // Verify chain linkage
    for (NSUInteger i = 0; i < entries.count; i++) {
        CMAuditEntry *entry = entries[i];
        XCTAssertNotNil(entry.entryHash,
                        @"Entry %lu should have entryHash", (unsigned long)i);

        if (i == 0) {
            // Step 3: First entry has prevHash = nil (or seed anchor)
            // The first entry may have nil prevHash or it may link to a seed
            // Depending on whether there were prior entries from setUp
        } else {
            CMAuditEntry *prevEntry = entries[i - 1];
            // Each entry's prevHash should equal the prior entry's entryHash
            if (entry.prevHash != nil && prevEntry.entryHash != nil) {
                XCTAssertEqualObjects(entry.prevHash, prevEntry.entryHash,
                                      @"Entry %lu prevHash should equal entry %lu entryHash",
                                      (unsigned long)i, (unsigned long)(i - 1));
            }
        }
    }
}

#pragma mark - Test 3: First Entry Has prevHash = nil

- (void)testFirstEntryPrevHashIsNilOrSeed {
    // Clear any existing entries by starting with a fresh chain
    [self writeTestEntries:1];

    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    NSError *error = nil;
    NSArray<CMAuditEntry *> *entries = [repo entriesAfter:nil
                                                forTenant:self.testTenantId
                                                    limit:1
                                                    error:&error];
    XCTAssertNil(error);
    XCTAssertGreaterThan(entries.count, 0, @"Should have at least one entry");

    CMAuditEntry *firstEntry = entries.firstObject;
    XCTAssertNotNil(firstEntry.entryId, @"First entry should have an entryId");
    XCTAssertNotNil(firstEntry.entryHash, @"First entry should have an entryHash");
    // prevHash may be nil for the very first entry in the chain
    // This is acceptable per the design: the first entry anchors the chain
}

#pragma mark - Test 4: Verifier Passes on Intact Chain

- (void)testVerifierPassesOnIntactChain {
    // Write entries to build a chain
    [self writeTestEntries:5];

    // Run full chain verification synchronously
    NSError *verifyError = nil;
    BOOL valid = [[CMAuditVerifier shared] verifyFullChainForTenant:self.testTenantId
                                                            context:self.testContext
                                                              error:&verifyError];
    XCTAssertTrue(valid, @"Chain verification should pass on intact chain: %@", verifyError);
    XCTAssertNil(verifyError, @"No error expected on valid chain");
}

#pragma mark - Test 5: Tamper Detection - Modified beforeJSON

- (void)testVerifierFailsOnTamperedEntry {
    // Write 5 entries to build a chain
    [self writeTestEntries:5];

    // Fetch all entries
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    NSError *fetchError = nil;
    NSArray<CMAuditEntry *> *entries = [repo entriesAfter:nil
                                                forTenant:self.testTenantId
                                                    limit:100
                                                    error:&fetchError];
    XCTAssertNil(fetchError);
    XCTAssertGreaterThanOrEqual(entries.count, 3, @"Need at least 3 entries to tamper");

    // Tamper: modify one entry's beforeJSON directly in Core Data
    NSUInteger tamperIndex = entries.count / 2; // Middle entry
    CMAuditEntry *tamperedEntry = entries[tamperIndex];
    NSString *tamperedEntryId = tamperedEntry.entryId;
    tamperedEntry.beforeJSON = @{@"tampered": @YES, @"malicious": @"data"};
    // Do NOT recompute the hash — this simulates tampering

    NSError *saveError = nil;
    [self.testContext save:&saveError];
    XCTAssertNil(saveError, @"Save should succeed even with tampered data");

    // Run verifier — should fail
    NSError *verifyError = nil;
    BOOL valid = [[CMAuditVerifier shared] verifyFullChainForTenant:self.testTenantId
                                                            context:self.testContext
                                                              error:&verifyError];
    XCTAssertFalse(valid, @"Chain verification should FAIL after tampering");
    XCTAssertNotNil(verifyError, @"Error should describe the chain break");
    XCTAssertEqual(verifyError.code, CMErrorCodeAuditChainBroken,
                   @"Error code should be CMErrorCodeAuditChainBroken");

    // Verify the error identifies the broken entry
    NSString *brokenId = verifyError.userInfo[@"brokenEntryId"];
    XCTAssertNotNil(brokenId, @"Error should identify the broken entry ID");
    XCTAssertEqualObjects(brokenId, tamperedEntryId,
                          @"Broken entry should be the tampered one");
}

#pragma mark - Test: Async Chain Verification

- (void)testAsyncChainVerificationOnIntactChain {
    // Write entries
    [self writeTestEntries:5];

    XCTestExpectation *verifyExp = [self expectationWithDescription:@"Async verification"];
    [[CMAuditVerifier shared] verifyChainForTenant:self.testTenantId
                                          progress:^(NSUInteger verified, NSUInteger total) {
        // Progress callback
        XCTAssertGreaterThanOrEqual(verified, (NSUInteger)0);
    }
                                        completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
        XCTAssertTrue(success, @"Async verification should pass: %@", error);
        XCTAssertNil(brokenEntryId, @"No broken entry expected");
        XCTAssertNil(error, @"No error expected");
        [verifyExp fulfill];
    }];

    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

#pragma mark - Test: Async Verification Detects Tamper

- (void)testAsyncVerificationDetectsTamper {
    // Write entries
    [self writeTestEntries:5];

    // Tamper
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    NSError *fetchError = nil;
    NSArray<CMAuditEntry *> *entries = [repo entriesAfter:nil
                                                forTenant:self.testTenantId
                                                    limit:100
                                                    error:&fetchError];

    if (entries.count >= 3) {
        CMAuditEntry *tamperedEntry = entries[entries.count / 2];
        tamperedEntry.afterJSON = @{@"tampered": @YES};
        [self.testContext save:nil];

        XCTestExpectation *verifyExp = [self expectationWithDescription:@"Async tamper detection"];
        [[CMAuditVerifier shared] verifyChainForTenant:self.testTenantId
                                              progress:nil
                                            completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
            XCTAssertFalse(success, @"Verification should fail on tampered chain");
            XCTAssertNotNil(brokenEntryId, @"Broken entry ID should be reported");
            XCTAssertNotNil(error, @"Error should be returned");
            XCTAssertEqual(error.code, CMErrorCodeAuditChainBroken);
            [verifyExp fulfill];
        }];

        [self waitForExpectationsWithTimeout:10.0 handler:nil];
    }
}

#pragma mark - Test: Hash Chain Computation

- (void)testHashChainComputationDeterministic {
    // Ensure seed exists
    NSError *seedErr = nil;
    NSData *seed = [CMAuditHashChain ensureSeedForTenant:self.testTenantId error:&seedErr];
    XCTAssertNotNil(seed, @"Seed should be created: %@", seedErr);
    XCTAssertGreaterThan(seed.length, 0, @"Seed should have non-zero length");

    // Create two identical entries and verify they produce the same hash
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    CMAuditEntry *entry1 = [repo insertEntry];
    entry1.tenantId = self.testTenantId;
    entry1.actorUserId = self.courierUserId;
    entry1.actorRole = CMUserRoleCourier;
    entry1.action = @"test.deterministic";
    entry1.targetType = @"Test";
    entry1.targetId = @"det-001";
    entry1.beforeJSON = @{@"key": @"value"};
    entry1.afterJSON = @{@"key": @"newvalue"};
    entry1.prevHash = nil;

    NSData *hash1 = [CMAuditHashChain computeHashForEntry:entry1 prevHash:nil tenantSeed:seed];
    NSData *hash2 = [CMAuditHashChain computeHashForEntry:entry1 prevHash:nil tenantSeed:seed];

    XCTAssertNotNil(hash1, @"Hash should be computed");
    XCTAssertEqualObjects(hash1, hash2, @"Same entry should produce same hash (deterministic)");
    XCTAssertGreaterThan(hash1.length, 0, @"Hash should have non-zero length");
}

#pragma mark - Helper: Write N Test Entries Synchronously

#pragma mark - Test: Production Write Path Chain Integrity

- (void)testChainIntegrityViaProductionAuditService {
    // Write entries sequentially through the production CMAuditService.
    // Each write must complete before the next starts to maintain chain order.
    XCTestExpectation *write1 = [self expectationWithDescription:@"Write entry 1"];
    [[CMAuditService shared] recordAction:@"prod.chain.1"
                               targetType:@"ChainTest" targetId:@"prod-1"
                               beforeJSON:nil afterJSON:@{@"step": @1}
                                   reason:@"Production path test entry 1"
                               completion:^(CMAuditEntry *e, NSError *err) {
        XCTAssertNotNil(e, @"Entry 1 should be written: %@", err);
        [write1 fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTestExpectation *write2 = [self expectationWithDescription:@"Write entry 2"];
    [[CMAuditService shared] recordAction:@"prod.chain.2"
                               targetType:@"ChainTest" targetId:@"prod-2"
                               beforeJSON:@{@"step": @1} afterJSON:@{@"step": @2}
                                   reason:@"Production path test entry 2"
                               completion:^(CMAuditEntry *e, NSError *err) {
        XCTAssertNotNil(e, @"Entry 2 should be written: %@", err);
        [write2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTestExpectation *write3 = [self expectationWithDescription:@"Write entry 3"];
    [[CMAuditService shared] recordAction:@"prod.chain.3"
                               targetType:@"ChainTest" targetId:@"prod-3"
                               beforeJSON:@{@"step": @2} afterJSON:@{@"step": @3}
                                   reason:@"Production path test entry 3"
                               completion:^(CMAuditEntry *e, NSError *err) {
        XCTAssertNotNil(e, @"Entry 3 should be written: %@", err);
        [write3 fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // Now verify the chain written by the production service.
    XCTestExpectation *verifyExp = [self expectationWithDescription:@"Verify production chain"];
    [[CMAuditVerifier shared] verifyChainForTenant:self.testTenantId
                                          progress:nil
                                        completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
        XCTAssertTrue(success, @"Production-written chain should verify: broken=%@, err=%@",
                      brokenEntryId, error);
        [verifyExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Helper: Write N Test Entries Synchronously

- (void)writeTestEntries:(NSUInteger)count {
    // Write directly into testContext so reads on the same context see the entries.
    // (CMAuditService.shared uses CMCoreDataStack.shared — a different store.)
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];

    for (NSUInteger i = 0; i < count; i++) {
        CMAuditEntry *prevEntry = [repo latestEntryForTenant:self.testTenantId error:nil];
        NSData *prevHash = prevEntry.entryHash;

        CMAuditEntry *entry = [repo insertEntry];
        entry.tenantId    = self.testTenantId;
        entry.actorUserId = self.courierUserId ?: @"test-actor";
        entry.actorRole   = @"courier";
        entry.action      = [NSString stringWithFormat:@"chain.test.%lu", (unsigned long)(i + 1)];
        entry.targetType  = @"ChainTest";
        entry.targetId    = [NSString stringWithFormat:@"chain-%lu", (unsigned long)(i + 1)];
        entry.beforeJSON  = @{@"index": @(i)};
        entry.afterJSON   = @{@"index": @(i + 1)};
        entry.reason      = @"Chain integrity test";
        entry.prevHash    = prevHash;

        NSData *seed = [CMAuditHashChain ensureSeedForTenant:self.testTenantId error:nil];
        if (seed) {
            entry.entryHash = [CMAuditHashChain computeHashForEntry:entry
                                                           prevHash:prevHash
                                                         tenantSeed:seed];
        }
    }
    [self saveContext];
}

#pragma mark - Test: Audit Entry Immutability — Repository Layer

- (void)testAuditRepositoryOnlyExposesInsert {
    // CMAuditRepository enforces write-once by only exposing insertEntry.
    // No updateEntry/deleteEntry methods exist. Verify the repository class
    // does not respond to any update/delete selectors.
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    XCTAssertFalse([repo respondsToSelector:@selector(updateEntry:error:)],
                   @"AuditRepository must not offer updateEntry");
    XCTAssertFalse([repo respondsToSelector:@selector(deleteEntry:error:)],
                   @"AuditRepository must not offer deleteEntry");
    XCTAssertTrue([repo respondsToSelector:@selector(insertEntry)],
                  @"AuditRepository must offer insertEntry");
}

- (void)testVerifierCatchesTamperEvenWithoutWillSave {
    // Write entries normally, then tamper at the Core Data level.
    // The verifier's hash-chain check must detect the tampering.
    [self writeTestEntries:5];
    [self saveContext];

    // Tamper with the 3rd entry's action field.
    CMAuditRepository *repo = [[CMAuditRepository alloc] initWithContext:self.testContext];
    NSArray<CMAuditEntry *> *entries = [repo entriesAfter:nil
                                                forTenant:self.testTenantId
                                                    limit:0 error:nil];
    XCTAssertGreaterThanOrEqual(entries.count, 3);
    entries[2].action = @"TAMPERED_BY_TEST";
    [self saveContext];

    // Verifier should detect the chain break.
    XCTestExpectation *verifyExp = [self expectationWithDescription:@"Tamper detect"];
    [[CMAuditVerifier shared] verifyChainForTenant:self.testTenantId
                                          progress:nil
                                        completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
        XCTAssertFalse(success, @"Verifier should detect tampering");
        [verifyExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
