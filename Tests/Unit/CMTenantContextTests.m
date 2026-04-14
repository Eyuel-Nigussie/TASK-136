//
//  CMTenantContextTests.m
//  CourierMatch
//
//  Unit tests for CMTenantContext — tenant scoping and auth state per S4.4.
//

#import <XCTest/XCTest.h>
#import "CMTenantContext.h"

@interface CMTenantContextTests : XCTestCase
@property (nonatomic, strong) CMTenantContext *ctx;
@end

@implementation CMTenantContextTests

- (void)setUp {
    [super setUp];
    // Create a fresh instance (not the singleton) for test isolation.
    self.ctx = [[CMTenantContext alloc] init];
}

- (void)tearDown {
    self.ctx = nil;
    [super tearDown];
}

#pragma mark - Initial state

- (void)testInitiallyNotAuthenticated {
    XCTAssertFalse([self.ctx isAuthenticated]);
}

- (void)testInitially_CurrentUserIdIsNil {
    XCTAssertNil(self.ctx.currentUserId);
}

- (void)testInitially_CurrentTenantIdIsNil {
    XCTAssertNil(self.ctx.currentTenantId);
}

- (void)testInitially_CurrentRoleIsNil {
    XCTAssertNil(self.ctx.currentRole);
}

#pragma mark - setUserId:tenantId:role:

- (void)testSetUserId_MakesAuthenticated {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"courier"];
    XCTAssertTrue([self.ctx isAuthenticated]);
}

- (void)testSetUserId_StoresValues {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"admin"];
    XCTAssertEqualObjects(self.ctx.currentUserId, @"user-1");
    XCTAssertEqualObjects(self.ctx.currentTenantId, @"tenant-1");
    XCTAssertEqualObjects(self.ctx.currentRole, @"admin");
}

#pragma mark - clear

- (void)testClear_MakesNotAuthenticated {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"courier"];
    XCTAssertTrue([self.ctx isAuthenticated]);
    [self.ctx clear];
    XCTAssertFalse([self.ctx isAuthenticated]);
}

- (void)testClear_NilsOutFields {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"courier"];
    [self.ctx clear];
    XCTAssertNil(self.ctx.currentUserId);
    XCTAssertNil(self.ctx.currentTenantId);
    XCTAssertNil(self.ctx.currentRole);
}

#pragma mark - scopingPredicate

- (void)testScopingPredicate_NilWhenNoTenant {
    NSPredicate *p = [self.ctx scopingPredicate];
    XCTAssertNil(p);
}

- (void)testScopingPredicate_ContainsTenantId {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-42" role:@"courier"];
    NSPredicate *p = [self.ctx scopingPredicate];
    XCTAssertNotNil(p);
    NSString *fmt = p.predicateFormat;
    XCTAssertTrue([fmt containsString:@"tenant-42"],
                  @"Scoping predicate should reference the tenant id, got: %@", fmt);
}

- (void)testScopingPredicate_ContainsDeletedAtNil {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-42" role:@"courier"];
    NSPredicate *p = [self.ctx scopingPredicate];
    NSString *fmt = p.predicateFormat;
    XCTAssertTrue([fmt containsString:@"deletedAt"] && [fmt containsString:@"nil"],
                  @"Scoping predicate should include 'deletedAt == nil', got: %@", fmt);
}

- (void)testScopingPredicate_NilAfterClear {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-42" role:@"courier"];
    [self.ctx clear];
    NSPredicate *p = [self.ctx scopingPredicate];
    XCTAssertNil(p);
}

#pragma mark - Notifications

- (void)testNotificationFires_OnSet {
    XCTestExpectation *exp = [self expectationForNotification:CMTenantContextDidChangeNotification
                                                       object:self.ctx
                                                      handler:nil];
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"courier"];
    [self waitForExpectations:@[exp] timeout:2.0];
}

- (void)testNotificationFires_OnClear {
    [self.ctx setUserId:@"user-1" tenantId:@"tenant-1" role:@"courier"];
    XCTestExpectation *exp = [self expectationForNotification:CMTenantContextDidChangeNotification
                                                       object:self.ctx
                                                      handler:nil];
    [self.ctx clear];
    [self waitForExpectations:@[exp] timeout:2.0];
}

@end
