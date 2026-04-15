//
//  CMPermissionChangeAuditorTests.m
//  CourierMatch Integration Tests
//

#import "CMIntegrationTestCase.h"
#import "CMPermissionChangeAuditor.h"
#import "CMAuditEntry.h"

@interface CMPermissionChangeAuditorTests : CMIntegrationTestCase
@end

@implementation CMPermissionChangeAuditorTests

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMPermissionChangeAuditor shared], [CMPermissionChangeAuditor shared]);
}

- (void)testRecordRoleChange {
    XCTestExpectation *exp = [self expectationWithDescription:@"role change"];
    [[CMPermissionChangeAuditor shared] recordRoleChange:@"user-1"
                                                 oldRole:@"courier"
                                                 newRole:@"reviewer"
                                                  reason:@"Test promotion"
                                              completion:^(CMAuditEntry *entry, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordRoleChangeNilReason {
    XCTestExpectation *exp = [self expectationWithDescription:@"nil reason"];
    [[CMPermissionChangeAuditor shared] recordRoleChange:@"user-2"
                                                 oldRole:@"courier"
                                                 newRole:@"admin"
                                                  reason:nil
                                              completion:^(CMAuditEntry *entry, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordRoleChangeNilCompletion {
    XCTAssertNoThrow([[CMPermissionChangeAuditor shared] recordRoleChange:@"user-3"
                                                                  oldRole:@"a"
                                                                  newRole:@"b"
                                                                   reason:@"r"
                                                               completion:nil]);
    [NSThread sleepForTimeInterval:0.5];
}

- (void)testRecordPermissionGrant {
    XCTestExpectation *exp = [self expectationWithDescription:@"grant"];
    [[CMPermissionChangeAuditor shared] recordPermissionGrant:@"user-4"
                                                   permission:@"orders.assign"
                                                       reason:@"Test grant"
                                                   completion:^(CMAuditEntry *e, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordPermissionRevoke {
    XCTestExpectation *exp = [self expectationWithDescription:@"revoke"];
    [[CMPermissionChangeAuditor shared] recordPermissionRevoke:@"user-5"
                                                    permission:@"orders.delete"
                                                        reason:@"Test revoke"
                                                    completion:^(CMAuditEntry *e, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testRecordBulkUpdate {
    XCTestExpectation *exp = [self expectationWithDescription:@"bulk"];
    [[CMPermissionChangeAuditor shared] recordPermissionBulkUpdate:@"user-6"
                                                          oldPerms:@{@"a": @YES, @"b": @NO}
                                                          newPerms:@{@"a": @NO, @"b": @YES, @"c": @YES}
                                                            reason:@"Bulk reset"
                                                        completion:^(CMAuditEntry *e, NSError *err) {
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
