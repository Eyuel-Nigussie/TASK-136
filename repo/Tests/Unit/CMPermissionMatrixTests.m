//
//  CMPermissionMatrixTests.m
//  CourierMatch Unit Tests
//
//  Covers CMPermissionMatrix.hasPermission:forRole: and allowedActionsForRole:
//

#import <XCTest/XCTest.h>
#import "CMPermissionMatrix.h"

@interface CMPermissionMatrixTests : XCTestCase
@property (nonatomic, strong) CMPermissionMatrix *matrix;
@end

@implementation CMPermissionMatrixTests

- (void)setUp {
    [super setUp];
    self.matrix = [CMPermissionMatrix shared];
}

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMPermissionMatrix shared], [CMPermissionMatrix shared]);
}

- (void)testHasPermission_NilActionReturnsFalse {
    BOOL result = [self.matrix hasPermission:nil forRole:@"admin"];
    XCTAssertFalse(result, @"nil action should return NO");
}

- (void)testHasPermission_NilRoleReturnsFalse {
    BOOL result = [self.matrix hasPermission:@"some.action" forRole:nil];
    XCTAssertFalse(result, @"nil role should return NO");
}

- (void)testHasPermission_UnknownRoleReturnsFalse {
    BOOL result = [self.matrix hasPermission:@"any.action" forRole:@"nonexistent_role"];
    XCTAssertFalse(result, @"Unknown role should not have any permissions");
}

- (void)testAllowedActionsForRole_NilRoleReturnsEmptyArray {
    NSArray *actions = [self.matrix allowedActionsForRole:nil];
    XCTAssertNotNil(actions, @"Should return empty array, not nil");
    XCTAssertEqual(actions.count, 0u, @"nil role should return empty array");
}

- (void)testAllowedActionsForRole_UnknownRoleReturnsEmptyArray {
    NSArray *actions = [self.matrix allowedActionsForRole:@"unknown_role_xyz"];
    XCTAssertNotNil(actions);
    XCTAssertEqual(actions.count, 0u, @"Unknown role should have no allowed actions");
}

- (void)testAllowedActionsForRole_KnownRolesReturnArrays {
    NSArray *roles = @[@"admin", @"dispatcher", @"courier", @"reviewer", @"cs", @"finance"];
    for (NSString *role in roles) {
        NSArray *actions = [self.matrix allowedActionsForRole:role];
        XCTAssertNotNil(actions,
                        @"allowedActionsForRole: should never return nil for role: %@", role);
    }
}

- (void)testAllowedActionsForRole_AdminHasMoreThanCourier {
    NSArray *adminActions = [self.matrix allowedActionsForRole:@"admin"];
    NSArray *courierActions = [self.matrix allowedActionsForRole:@"courier"];
    XCTAssertGreaterThan(adminActions.count, courierActions.count,
                         @"Admin must have strictly more permissions than courier");
}

- (void)testAllowedActionsForRole_KnownRolesHaveNonEmptyActionSets {
    // Each active role must have at least one permitted action; an empty set
    // would mean the role is defined but useless.
    NSArray *roles = @[@"admin", @"dispatcher", @"courier", @"reviewer", @"cs", @"finance"];
    for (NSString *role in roles) {
        NSArray *actions = [self.matrix allowedActionsForRole:role];
        XCTAssertGreaterThan(actions.count, 0u,
                             @"Role '%@' must have at least one permitted action", role);
    }
}

- (void)testHasPermission_CourierCanOpenAppeal {
    // Couriers must be able to open appeals against their own scorecards.
    BOOL allowed = [self.matrix hasPermission:@"appeals.open" forRole:@"courier"];
    XCTAssertTrue(allowed, @"courier must have appeals.open permission");
}

- (void)testHasPermission_CourierCannotCloseAppeal {
    // Only reviewers/admins can close appeals; couriers must not.
    BOOL allowed = [self.matrix hasPermission:@"appeals.close" forRole:@"courier"];
    XCTAssertFalse(allowed, @"courier must not have appeals.close permission");
}

- (void)testHasPermission_ReviewerCanGradeManual {
    BOOL allowed = [self.matrix hasPermission:@"appeals.grade_manual" forRole:@"reviewer"];
    XCTAssertTrue(allowed, @"reviewer must have appeals.grade_manual permission");
}

- (void)testHasPermission_CourierCannotGradeManual {
    BOOL allowed = [self.matrix hasPermission:@"appeals.grade_manual" forRole:@"courier"];
    XCTAssertFalse(allowed, @"courier must not have appeals.grade_manual permission");
}

- (void)testHasPermission_AdminCanManageTenants {
    BOOL allowed = [self.matrix hasPermission:@"tenants.manage" forRole:@"admin"];
    XCTAssertTrue(allowed, @"admin must have tenants.manage permission");
}

- (void)testHasPermission_DispatcherCannotManageTenants {
    BOOL allowed = [self.matrix hasPermission:@"tenants.manage" forRole:@"dispatcher"];
    XCTAssertFalse(allowed, @"dispatcher must not have tenants.manage permission");
}

- (void)testHasPermission_ReviewerCanDecideAppeal {
    BOOL allowed = [self.matrix hasPermission:@"appeals.decide" forRole:@"reviewer"];
    XCTAssertTrue(allowed, @"reviewer must have appeals.decide permission");
}

- (void)testHasPermission_CourierCannotDecideAppeal {
    BOOL allowed = [self.matrix hasPermission:@"appeals.decide" forRole:@"courier"];
    XCTAssertFalse(allowed, @"courier must not have appeals.decide permission");
}

- (void)testHasPermission_FinanceCanCloseMonetaryAppeals {
    BOOL allowed = [self.matrix hasPermission:@"appeals.close_monetary" forRole:@"finance"];
    XCTAssertTrue(allowed, @"finance must have appeals.close_monetary permission");
}

- (void)testHasPermission_CourierCannotCloseMonetaryAppeals {
    BOOL allowed = [self.matrix hasPermission:@"appeals.close_monetary" forRole:@"courier"];
    XCTAssertFalse(allowed, @"courier must not have appeals.close_monetary permission");
}

@end
