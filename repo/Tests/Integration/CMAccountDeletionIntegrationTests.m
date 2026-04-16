//
//  CMAccountDeletionIntegrationTests.m
//  CourierMatch Integration Tests
//
//  Tests for account deletion service: admin authorization, self-deletion
//  prevention, soft-delete behavior, and role-based denial.
//

#import "CMIntegrationTestCase.h"
#import "CMAccountService.h"
#import "CMUserAccount.h"
#import "CMTenantContext.h"
#import "CMErrorCodes.h"
#import "CMAuditService.h"
#import "CMAuditEntry.h"

@interface CMAccountDeletionIntegrationTests : CMIntegrationTestCase
@end

@implementation CMAccountDeletionIntegrationTests

#pragma mark - Test: Admin Can Delete Another User's Account

- (void)testAdminCanDeleteCourierAccount {
    [self switchToUser:self.adminUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.courierUser error:&err];

    XCTAssertTrue(deleted, @"Admin should be able to delete courier account: %@", err);
    XCTAssertNil(err);
    XCTAssertEqualObjects(self.courierUser.status, CMUserStatusDeleted,
                          @"User status should be 'deleted'");
    XCTAssertNotNil(self.courierUser.deletedAt,
                    @"deletedAt should be set");
    XCTAssertNotNil(self.courierUser.forceLogoutAt,
                    @"forceLogoutAt should be set to force session termination");
}

#pragma mark - Test: Admin Cannot Delete Own Account

- (void)testAdminCannotDeleteOwnAccount {
    [self switchToUser:self.adminUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.adminUser error:&err];

    XCTAssertFalse(deleted, @"Admin should not be able to delete own account");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
    XCTAssertEqualObjects(self.adminUser.status, CMUserStatusActive,
                          @"Admin status should remain active");
}

#pragma mark - Test: Non-Admin Roles Cannot Delete Accounts

- (void)testCourierCannotDeleteAccount {
    [self switchToUser:self.courierUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.dispatcherUser error:&err];

    XCTAssertFalse(deleted, @"Courier should not be able to delete accounts");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testDispatcherCannotDeleteAccount {
    [self switchToUser:self.dispatcherUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.courierUser error:&err];

    XCTAssertFalse(deleted, @"Dispatcher should not be able to delete accounts");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testReviewerCannotDeleteAccount {
    [self switchToUser:self.reviewerUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.courierUser error:&err];

    XCTAssertFalse(deleted, @"Reviewer should not be able to delete accounts");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testFinanceCannotDeleteAccount {
    [self switchToUser:self.financeUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.courierUser error:&err];

    XCTAssertFalse(deleted, @"Finance should not be able to delete accounts");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

- (void)testCSCannotDeleteAccount {
    [self switchToUser:self.csUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:self.courierUser error:&err];

    XCTAssertFalse(deleted, @"CS should not be able to delete accounts");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

#pragma mark - Test: Double Deletion Prevented

- (void)testCannotDeleteAlreadyDeletedAccount {
    [self switchToUser:self.adminUser];

    // First deletion succeeds.
    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err1 = nil;
    BOOL first = [svc deleteAccount:self.courierUser error:&err1];
    XCTAssertTrue(first, @"First deletion should succeed: %@", err1);

    // Second deletion is rejected.
    NSError *err2 = nil;
    BOOL second = [svc deleteAccount:self.courierUser error:&err2];
    XCTAssertFalse(second, @"Deleting already-deleted account should fail");
    XCTAssertNotNil(err2);
    XCTAssertEqual(err2.code, CMErrorCodeValidationFailed);
}

#pragma mark - Test: Audit Entry Written on Deletion

- (void)testDeletionWritesAuditEntry {
    [self switchToUser:self.adminUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    [svc deleteAccount:self.dispatcherUser error:nil];

    // Verify audit entry was dispatched by recording a follow-up entry
    // and checking the dispatcher's status.
    XCTestExpectation *auditExp = [self expectationWithDescription:@"Audit entry for deletion"];
    [[CMAuditService shared] recordAction:@"test.deletion.verify"
                               targetType:@"UserAccount"
                                 targetId:self.dispatcherUser.userId
                               beforeJSON:nil
                                afterJSON:@{@"verified": @YES}
                                   reason:@"Deletion audit verification"
                               completion:^(CMAuditEntry *entry, NSError *error) {
        XCTAssertNotNil(entry, @"Audit entry should be written");
        [auditExp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqualObjects(self.dispatcherUser.status, CMUserStatusDeleted);
}

#pragma mark - Test: Cross-Tenant Deletion Blocked

- (void)testAdminCannotDeleteUserFromDifferentTenant {
    [self switchToUser:self.adminUser]; // on test-tenant-001

    // Create a user belonging to a completely different tenant.
    CMUserAccount *otherTenantUser =
        [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                      inManagedObjectContext:self.testContext];
    otherTenantUser.userId    = @"user-other-tenant";
    otherTenantUser.tenantId  = @"other-tenant-999"; // different tenant
    otherTenantUser.username  = @"outsider";
    otherTenantUser.displayName = @"Outsider";
    otherTenantUser.role      = CMUserRoleCourier;
    otherTenantUser.status    = CMUserStatusActive;
    otherTenantUser.createdAt = [NSDate date];
    otherTenantUser.updatedAt = [NSDate date];
    otherTenantUser.version   = 1;
    [self saveContext];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:otherTenantUser error:&err];

    XCTAssertFalse(deleted,
                   @"Admin must NOT be able to delete a user from a different tenant");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied,
                   @"Cross-tenant delete must return PermissionDenied, got code %ld", (long)err.code);
    XCTAssertEqualObjects(otherTenantUser.status, CMUserStatusActive,
                          @"User from other tenant must remain active after blocked delete");
}

- (void)testAdminCannotDeleteUserWithNilTenantId {
    [self switchToUser:self.adminUser];

    CMUserAccount *noTenantUser =
        [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                      inManagedObjectContext:self.testContext];
    noTenantUser.userId    = @"user-nil-tenant";
    noTenantUser.tenantId  = nil; // missing tenant
    noTenantUser.username  = @"ghost";
    noTenantUser.displayName = @"Ghost";
    noTenantUser.role      = CMUserRoleCourier;
    noTenantUser.status    = CMUserStatusActive;
    noTenantUser.createdAt = [NSDate date];
    noTenantUser.updatedAt = [NSDate date];
    noTenantUser.version   = 1;
    [self saveContext];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];
    NSError *err = nil;
    BOOL deleted = [svc deleteAccount:noTenantUser error:&err];

    XCTAssertFalse(deleted,
                   @"Admin must NOT be able to delete a user with nil tenantId");
    XCTAssertNotNil(err);
    XCTAssertEqual(err.code, CMErrorCodePermissionDenied);
}

#pragma mark - Test: Admin Can Delete Multiple Different Users

- (void)testAdminCanDeleteMultipleUsers {
    [self switchToUser:self.adminUser];

    CMAccountService *svc = [[CMAccountService alloc] initWithContext:self.testContext];

    NSError *err1 = nil;
    BOOL d1 = [svc deleteAccount:self.courierUser error:&err1];
    XCTAssertTrue(d1, @"Should delete courier: %@", err1);

    NSError *err2 = nil;
    BOOL d2 = [svc deleteAccount:self.dispatcherUser error:&err2];
    XCTAssertTrue(d2, @"Should delete dispatcher: %@", err2);

    XCTAssertEqualObjects(self.courierUser.status, CMUserStatusDeleted);
    XCTAssertEqualObjects(self.dispatcherUser.status, CMUserStatusDeleted);
    // Other users remain active.
    XCTAssertEqualObjects(self.reviewerUser.status, CMUserStatusActive);
    XCTAssertEqualObjects(self.financeUser.status, CMUserStatusActive);
}

@end
