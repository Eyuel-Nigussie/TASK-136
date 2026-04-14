//
//  CMLockoutPolicyTests.m
//  CourierMatch
//
//  Unit tests for CMLockoutPolicy — failed-attempt lockout per design.md S4.1.
//  We build an in-memory Core Data stack with the real UserAccount entity so
//  the CMUserAccount managed-object properties work correctly.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import "CMLockoutPolicy.h"
#import "CMUserAccount.h"

@interface CMLockoutPolicyTests : XCTestCase
@property (nonatomic, strong) NSPersistentContainer *container;
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMLockoutPolicyTests

#pragma mark - In-memory Core Data helpers

- (NSManagedObjectModel *)userAccountModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = @"UserAccount";
    entity.managedObjectClassName = @"CMUserAccount";

    NSMutableArray<NSAttributeDescription *> *attrs = [NSMutableArray array];

    void (^addString)(NSString *, BOOL) = ^(NSString *name, BOOL optional) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name;
        a.attributeType = NSStringAttributeType;
        a.optional = optional;
        [attrs addObject:a];
    };
    void (^addDate)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name;
        a.attributeType = NSDateAttributeType;
        a.optional = YES;
        [attrs addObject:a];
    };

    addString(@"userId", NO);
    addString(@"tenantId", NO);
    addString(@"username", NO);
    addString(@"displayName", YES);
    addString(@"role", NO);
    addString(@"status", NO);
    addString(@"biometricRefId", YES);
    addString(@"createdBy", YES);
    addString(@"updatedBy", YES);

    // Binary
    for (NSString *n in @[@"passwordHash", @"passwordSalt"]) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = n;
        a.attributeType = NSBinaryDataAttributeType;
        a.optional = YES;
        [attrs addObject:a];
    }

    // Integer 64
    for (NSString *n in @[@"passwordIterations", @"version"]) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = n;
        a.attributeType = NSInteger64AttributeType;
        a.optional = NO;
        a.defaultValue = @(0);
        [attrs addObject:a];
    }

    // Integer 16 — failedAttempts
    {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = @"failedAttempts";
        a.attributeType = NSInteger16AttributeType;
        a.optional = NO;
        a.defaultValue = @(0);
        [attrs addObject:a];
    }

    // Boolean
    {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = @"biometricEnabled";
        a.attributeType = NSBooleanAttributeType;
        a.optional = NO;
        a.defaultValue = @(NO);
        [attrs addObject:a];
    }

    // Dates
    for (NSString *n in @[@"lockUntil", @"passwordUpdatedAt", @"lastLoginAt",
                          @"forceLogoutAt", @"createdAt", @"updatedAt", @"deletedAt"]) {
        addDate(n);
    }

    entity.properties = attrs;
    model.entities = @[entity];
    return model;
}

- (CMUserAccount *)freshUser {
    CMUserAccount *u = [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                                    inManagedObjectContext:self.context];
    u.userId    = [[NSUUID UUID] UUIDString];
    u.tenantId  = @"tenant-1";
    u.username  = @"testuser";
    u.role      = CMUserRoleCourier;
    u.status    = CMUserStatusActive;
    u.createdAt = [NSDate date];
    u.updatedAt = [NSDate date];
    return u;
}

- (void)setUp {
    [super setUp];
    NSManagedObjectModel *model = [self userAccountModel];
    self.container = [[NSPersistentContainer alloc] initWithName:@"TestStore"
                                             managedObjectModel:model];
    NSPersistentStoreDescription *desc = [[NSPersistentStoreDescription alloc] init];
    desc.type = NSInMemoryStoreType;
    self.container.persistentStoreDescriptions = @[desc];

    XCTestExpectation *loaded = [self expectationWithDescription:@"Store loaded"];
    [self.container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *d, NSError *e) {
        XCTAssertNil(e, @"Failed to load in-memory store: %@", e);
        [loaded fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    self.context = self.container.viewContext;
}

- (void)tearDown {
    self.context = nil;
    self.container = nil;
    [super tearDown];
}

#pragma mark - Thresholds

- (void)testClassProperties {
    XCTAssertEqual([CMLockoutPolicy captchaThreshold], 3u);
    XCTAssertEqual([CMLockoutPolicy lockoutThreshold], 5u);
    XCTAssertEqualWithAccuracy([CMLockoutPolicy lockoutDuration], 600.0, 0.01);
}

#pragma mark - applyFailureTo

- (void)testOneFailure_IncrementsButDoesNotLock {
    CMUserAccount *u = [self freshUser];
    [CMLockoutPolicy applyFailureTo:u];
    XCTAssertEqual(u.failedAttempts, 1);
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertNil(u.lockUntil);
}

- (void)testTwoFailures_IncrementsButDoesNotLock {
    CMUserAccount *u = [self freshUser];
    [CMLockoutPolicy applyFailureTo:u];
    [CMLockoutPolicy applyFailureTo:u];
    XCTAssertEqual(u.failedAttempts, 2);
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertNil(u.lockUntil);
}

- (void)testThreeFailures_SetsRequiresCaptcha {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 3; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    XCTAssertEqual(u.failedAttempts, 3);
    // Account is not locked yet but CAPTCHA threshold reached.
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertTrue([u requiresCaptchaNextAttempt]);
}

- (void)testFourFailures_StillNotLocked {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 4; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    XCTAssertEqual(u.failedAttempts, 4);
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertNil(u.lockUntil);
}

- (void)testFiveFailures_LocksAccountFor10Minutes {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    XCTAssertEqual(u.failedAttempts, 5);
    XCTAssertEqualObjects(u.status, CMUserStatusLocked);
    XCTAssertNotNil(u.lockUntil);
    // lockUntil should be approximately now + 600 s.
    NSTimeInterval delta = [u.lockUntil timeIntervalSinceNow];
    XCTAssertEqualWithAccuracy(delta, 600.0, 2.0);
}

#pragma mark - applySuccessTo

- (void)testApplySuccess_ResetsFailedAttempts {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    XCTAssertEqual(u.failedAttempts, 5);
    [CMLockoutPolicy applySuccessTo:u];
    XCTAssertEqual(u.failedAttempts, 0);
    XCTAssertNil(u.lockUntil);
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertNotNil(u.lastLoginAt);
}

- (void)testApplySuccess_ClearsLockUntil {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    [CMLockoutPolicy applySuccessTo:u];
    XCTAssertNil(u.lockUntil);
}

#pragma mark - maybeClearExpiredLockOn

- (void)testMaybeClearExpired_ActiveAccount_ReturnsNO {
    CMUserAccount *u = [self freshUser];
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:u];
    XCTAssertFalse(cleared);
}

- (void)testMaybeClearExpired_LockStillActive_ReturnsNO {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    // Lock is in the future.
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:u];
    XCTAssertFalse(cleared);
    XCTAssertEqualObjects(u.status, CMUserStatusLocked);
}

- (void)testMaybeClearExpired_LockExpired_ReturnsYESAndClearsStatus {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    // Simulate an expired lock by setting lockUntil to the past.
    u.lockUntil = [NSDate dateWithTimeIntervalSinceNow:-1];
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:u];
    XCTAssertTrue(cleared);
    XCTAssertEqualObjects(u.status, CMUserStatusActive);
    XCTAssertNil(u.lockUntil);
}

- (void)testMaybeClearExpired_FailedAttemptsPreservedAfterExpiredLock {
    CMUserAccount *u = [self freshUser];
    for (int i = 0; i < 5; i++) { [CMLockoutPolicy applyFailureTo:u]; }
    u.lockUntil = [NSDate dateWithTimeIntervalSinceNow:-1];
    [CMLockoutPolicy maybeClearExpiredLockOn:u];
    // The failure counter must survive unlock so the next failure is
    // immediately CAPTCHA-gated.
    XCTAssertGreaterThanOrEqual(u.failedAttempts, 3);
    XCTAssertEqual(u.failedAttempts, 5);
}

- (void)testMaybeClearExpired_NilUser_ReturnsNO {
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:nil];
    XCTAssertFalse(cleared);
}

- (void)testMaybeClearExpired_LockedButNoLockUntil_ReturnsNO {
    CMUserAccount *u = [self freshUser];
    u.status = CMUserStatusLocked;
    u.lockUntil = nil;
    BOOL cleared = [CMLockoutPolicy maybeClearExpiredLockOn:u];
    XCTAssertFalse(cleared);
}

@end
