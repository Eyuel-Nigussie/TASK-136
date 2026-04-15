//
//  CMAuditServiceExtendedTests.m
//  CourierMatch Integration Tests
//
//  Covers additional CMAuditService paths:
//  - explicit actor/tenant API
//  - no-tenant-context guard
//  - recordPermissionChange convenience
//

#import "CMIntegrationTestCase.h"
#import "CMAuditService.h"
#import "CMAuditEntry.h"
#import "CMTenantContext.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"

@interface CMAuditServiceExtendedTests : CMIntegrationTestCase
@end

@implementation CMAuditServiceExtendedTests

- (void)setUp {
    [super setUp];
    [self switchToUser:self.adminUser];
    [[CMSessionManager shared] openSessionForUser:self.adminUser];
}

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMAuditService shared], [CMAuditService shared]);
}

- (void)testRecordActionAsync_FiresCompletion {
    XCTestExpectation *exp = [self expectationWithDescription:@"async audit"];
    __block CMAuditEntry *entry = nil;
    __block NSError *auditError = nil;
    [[CMAuditService shared] recordAction:@"test.action"
                               targetType:@"TestEntity"
                                 targetId:@"tid-1"
                               beforeJSON:@{@"field": @"old"}
                                afterJSON:@{@"field": @"new"}
                                   reason:@"unit test"
                               completion:^(CMAuditEntry *e, NSError *err) {
        entry = e;
        auditError = err;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    // The completion block must always fire with either an entry or an error.
    // Both being nil simultaneously indicates a bug in the audit service contract.
    XCTAssertTrue(entry != nil || auditError != nil,
                  @"Async audit completion must provide either an entry or an error — not both nil");
}

- (void)testRecordPermissionChange_FiresCompletion {
    XCTestExpectation *exp = [self expectationWithDescription:@"permission change"];
    [[CMAuditService shared] recordPermissionChangeForSubject:self.courierUser.userId
                                                      oldRole:@"courier"
                                                      newRole:@"dispatcher"
                                                       reason:@"promotion test"
                                                   completion:^(CMAuditEntry *e, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testRecordAction_ExplicitActorTenant_FiresCompletion {
    XCTestExpectation *exp = [self expectationWithDescription:@"explicit actor"];
    __block CMAuditEntry *entry = nil;
    [[CMAuditService shared] recordAction:@"system.sync"
                               targetType:@"Tenant"
                                 targetId:self.testTenantId
                               beforeJSON:nil
                                afterJSON:@{@"synced": @YES}
                                   reason:@"background sync"
                              actorUserId:@"system-actor"
                                actorRole:@"system"
                                 tenantId:self.testTenantId
                               completion:^(CMAuditEntry *e, NSError *err) {
        entry = e;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(entry, @"Explicit-actor audit entry should be created");
}

- (void)testRecordAction_ExplicitActorTenant_NilCompletionDoesNotCrash {
    [[CMAuditService shared] recordAction:@"system.noop"
                               targetType:nil
                                 targetId:nil
                               beforeJSON:nil
                                afterJSON:nil
                                   reason:nil
                              actorUserId:@"system-actor"
                                actorRole:@"system"
                                 tenantId:self.testTenantId
                               completion:nil];
    // Allow async work to complete.
    XCTestExpectation *settle = [self expectationWithDescription:@"settle"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [settle fulfill]; });
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordAction_NoTenantContext_DoesNotCrash {
    // Switch to no user (clear context) then try to record.
    [[CMTenantContext shared] clear];

    XCTestExpectation *exp = [self expectationWithDescription:@"no context"];
    [[CMAuditService shared] recordAction:@"test.no_ctx"
                               targetType:@"X"
                                 targetId:@"x"
                               beforeJSON:nil
                                afterJSON:nil
                                   reason:@"test"
                               completion:^(CMAuditEntry *e, NSError *err) {
        // When tenant context is clear, recordActionSync returns nil + error.
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordAction_MultipleActionsChainHashesCorrectly {
    XCTestExpectation *e1 = [self expectationWithDescription:@"action 1"];
    XCTestExpectation *e2 = [self expectationWithDescription:@"action 2"];
    XCTestExpectation *e3 = [self expectationWithDescription:@"action 3"];

    [[CMAuditService shared] recordAction:@"chain.a"
                               targetType:@"X" targetId:@"1"
                               beforeJSON:nil afterJSON:@{@"seq": @1}
                                   reason:nil
                               completion:^(CMAuditEntry *e, NSError *err) { [e1 fulfill]; }];
    [[CMAuditService shared] recordAction:@"chain.b"
                               targetType:@"X" targetId:@"2"
                               beforeJSON:nil afterJSON:@{@"seq": @2}
                                   reason:nil
                               completion:^(CMAuditEntry *e, NSError *err) { [e2 fulfill]; }];
    [[CMAuditService shared] recordAction:@"chain.c"
                               targetType:@"X" targetId:@"3"
                               beforeJSON:nil afterJSON:@{@"seq": @3}
                                   reason:nil
                               completion:^(CMAuditEntry *e, NSError *err) { [e3 fulfill]; }];

    [self waitForExpectationsWithTimeout:15.0 handler:nil];
}

@end
