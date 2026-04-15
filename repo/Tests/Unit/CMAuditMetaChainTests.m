//
//  CMAuditMetaChainTests.m
//  CourierMatch Tests
//

#import <XCTest/XCTest.h>
#import "CMAuditMetaChain.h"

@interface CMAuditMetaChainTests : XCTestCase
@end

@implementation CMAuditMetaChainTests

- (void)testSharedSingleton {
    XCTAssertEqual([CMAuditMetaChain shared], [CMAuditMetaChain shared]);
}

- (void)testRecordHeadChange {
    NSData *head = [@"first-head" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err = nil;
    BOOL ok = [[CMAuditMetaChain shared] recordHeadChangeForTenant:@"meta-tenant-1"
                                                            newHead:head
                                                        actorUserId:@"actor-1"
                                                              error:&err];
    XCTAssertTrue(ok, @"recordHeadChange should succeed: %@", err);
}

- (void)testRecordMultipleEntries {
    for (int i = 0; i < 5; i++) {
        NSString *headStr = [NSString stringWithFormat:@"head-%d", i];
        NSData *head = [headStr dataUsingEncoding:NSUTF8StringEncoding];
        BOOL ok = [[CMAuditMetaChain shared] recordHeadChangeForTenant:@"meta-tenant-multi"
                                                                newHead:head
                                                            actorUserId:@"actor-x"
                                                                  error:nil];
        XCTAssertTrue(ok);
    }
}

- (void)testAllEntriesReturnsArray {
    NSData *head = [@"any-head" dataUsingEncoding:NSUTF8StringEncoding];
    [[CMAuditMetaChain shared] recordHeadChangeForTenant:@"any-tenant"
                                                  newHead:head
                                              actorUserId:@"any-actor"
                                                    error:nil];
    NSArray *entries = [[CMAuditMetaChain shared] allEntries];
    XCTAssertNotNil(entries);
    XCTAssertGreaterThan(entries.count, (NSUInteger)0);
}

- (void)testVerifyChainPasses {
    NSError *err = nil;
    BOOL valid = [[CMAuditMetaChain shared] verifyChain:&err];
    XCTAssertTrue(valid, @"Chain should verify clean");
}

- (void)testLatestEntryForTenant {
    NSData *head = [@"latest-head" dataUsingEncoding:NSUTF8StringEncoding];
    [[CMAuditMetaChain shared] recordHeadChangeForTenant:@"latest-tenant"
                                                  newHead:head
                                              actorUserId:@"latest-actor"
                                                    error:nil];
    CMAuditMetaEntry *entry = [[CMAuditMetaChain shared] latestEntryForTenant:@"latest-tenant"];
    XCTAssertNotNil(entry);
    XCTAssertEqualObjects(entry.tenantId, @"latest-tenant");
    XCTAssertEqualObjects(entry.actorUserId, @"latest-actor");
}

- (void)testLatestEntryNoSuchTenant {
    CMAuditMetaEntry *entry = [[CMAuditMetaChain shared]
        latestEntryForTenant:@"never-existed-tenant"];
    XCTAssertNil(entry);
}

- (void)testMetaEntrySecureCoding {
    NSData *head = [@"sc-head" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *prev = [@"sc-prev" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hash = [@"sc-hash" dataUsingEncoding:NSUTF8StringEncoding];
    CMAuditMetaEntry *e = [[CMAuditMetaEntry alloc] initWithTenantId:@"sc-tenant"
                                                              newHead:head
                                                          actorUserId:@"sc-actor"
                                                            timestamp:[NSDate date]
                                                             prevHash:prev
                                                            entryHash:hash];
    XCTAssertNotNil(e);
    XCTAssertTrue([CMAuditMetaEntry supportsSecureCoding]);

    NSError *err = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:e
                                         requiringSecureCoding:YES error:&err];
    XCTAssertNotNil(data);
    CMAuditMetaEntry *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CMAuditMetaEntry class]
                                                                  fromData:data error:&err];
    XCTAssertNotNil(decoded);
    XCTAssertEqualObjects(decoded.tenantId, @"sc-tenant");
}

@end
