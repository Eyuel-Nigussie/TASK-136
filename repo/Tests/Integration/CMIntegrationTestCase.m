//
//  CMIntegrationTestCase.m
//  CourierMatch Integration Tests
//

#import "CMIntegrationTestCase.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMTenant.h"
#import "CMUserAccount.h"
#import "CMOrder.h"
#import "CMItinerary.h"
#import "CMRubricTemplate.h"
#import "CMAddress.h"
#import "CMDispute.h"
#import "CMAppeal.h"
#import "CMDeliveryScorecard.h"
#import "CMMatchCandidate.h"
#import "CMNotificationItem.h"
#import "CMAuditEntry.h"
#import "CMLoginHistory.h"
#import "CMWorkEntities.h"
#import "CMEncryptedValueTransformer.h"
#import "CMAddressTransformer.h"

static NSString * const kTestTenantId = @"test-tenant-001";
static NSString * const kTestTenantName = @"Test Tenant";

@implementation CMIntegrationTestCase

#pragma mark - Programmatic Model Builder

/// Builds the Core Data model programmatically as a fallback when the .momd
/// bundle is not available in the test target. Mirrors CMTestCoreDataHelper.
+ (NSManagedObjectModel *)buildProgrammaticModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    // Helper blocks for attribute construction
    NSAttributeDescription *(^strAttr)(NSString *, BOOL) = ^(NSString *name, BOOL optional) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSStringAttributeType; a.optional = optional;
        return a;
    };
    NSAttributeDescription *(^strAttrDef)(NSString *, NSString *) = ^(NSString *name, NSString *dv) {
        NSAttributeDescription *a = strAttr(name, NO); a.defaultValue = dv; return a;
    };
    NSAttributeDescription *(^dateAttr)(NSString *, BOOL) = ^(NSString *name, BOOL optional) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSDateAttributeType; a.optional = optional;
        return a;
    };
    NSAttributeDescription *(^dblAttr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSDoubleAttributeType; a.defaultValue = @(0.0);
        return a;
    };
    NSAttributeDescription *(^i64Attr)(NSString *, int64_t) = ^(NSString *name, int64_t dv) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSInteger64AttributeType; a.defaultValue = @(dv);
        return a;
    };
    NSAttributeDescription *(^i32Attr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSInteger32AttributeType; a.defaultValue = @(0);
        return a;
    };
    NSAttributeDescription *(^i16Attr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSInteger16AttributeType; a.defaultValue = @(0);
        return a;
    };
    NSAttributeDescription *(^boolAttr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSBooleanAttributeType; a.defaultValue = @(NO);
        return a;
    };
    NSAttributeDescription *(^transAttr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSTransformableAttributeType; a.optional = YES;
        return a;
    };
    NSAttributeDescription *(^binAttr)(NSString *) = ^(NSString *name) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name; a.attributeType = NSBinaryDataAttributeType; a.optional = YES;
        return a;
    };

    // --- Entities ---

    // Tenant
    NSEntityDescription *tenant = [[NSEntityDescription alloc] init];
    tenant.name = @"Tenant"; tenant.managedObjectClassName = @"CMTenant";
    tenant.properties = @[strAttr(@"tenantId",NO), strAttr(@"name",NO), strAttrDef(@"status",@"active"),
                          transAttr(@"configJSON"), dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO),
                          dateAttr(@"deletedAt",YES), strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES),
                          i64Attr(@"version",1)];

    // UserAccount
    NSEntityDescription *userAccount = [[NSEntityDescription alloc] init];
    userAccount.name = @"UserAccount"; userAccount.managedObjectClassName = @"CMUserAccount";
    userAccount.properties = @[strAttr(@"userId",NO), strAttr(@"tenantId",NO), strAttr(@"username",NO),
                               strAttr(@"displayName",YES), binAttr(@"passwordHash"), binAttr(@"passwordSalt"),
                               i64Attr(@"passwordIterations",0), dateAttr(@"passwordUpdatedAt",YES),
                               strAttrDef(@"role",@"courier"), strAttrDef(@"status",@"active"),
                               i16Attr(@"failedAttempts"), dateAttr(@"lockUntil",YES),
                               boolAttr(@"biometricEnabled"), strAttr(@"biometricRefId",YES),
                               dateAttr(@"lastLoginAt",YES), dateAttr(@"forceLogoutAt",YES),
                               dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                               strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // Order
    NSEntityDescription *order = [[NSEntityDescription alloc] init];
    order.name = @"Order"; order.managedObjectClassName = @"CMOrder";
    order.properties = @[strAttr(@"orderId",NO), strAttr(@"tenantId",NO), strAttr(@"externalOrderRef",NO),
                         transAttr(@"pickupAddress"), transAttr(@"dropoffAddress"),
                         dateAttr(@"pickupWindowStart",YES), dateAttr(@"pickupWindowEnd",YES),
                         dateAttr(@"dropoffWindowStart",YES), dateAttr(@"dropoffWindowEnd",YES),
                         strAttr(@"pickupTimeZoneIdentifier",YES), strAttr(@"dropoffTimeZoneIdentifier",YES),
                         dblAttr(@"parcelVolumeL"), dblAttr(@"parcelWeightKg"),
                         strAttr(@"requiresVehicleType",YES), strAttrDef(@"status",@"new"),
                         strAttr(@"assignedCourierId",YES), strAttr(@"customerNotes",YES),
                         binAttr(@"sensitiveCustomerId"),
                         dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                         strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // Itinerary
    NSEntityDescription *itinerary = [[NSEntityDescription alloc] init];
    itinerary.name = @"Itinerary"; itinerary.managedObjectClassName = @"CMItinerary";
    itinerary.properties = @[strAttr(@"itineraryId",NO), strAttr(@"tenantId",NO), strAttr(@"courierId",NO),
                             transAttr(@"originAddress"), transAttr(@"destinationAddress"),
                             dateAttr(@"departureWindowStart",YES), dateAttr(@"departureWindowEnd",YES),
                             strAttrDef(@"vehicleType",@"car"), dblAttr(@"vehicleCapacityVolumeL"),
                             dblAttr(@"vehicleCapacityWeightKg"), transAttr(@"onTheWayStops"),
                             strAttrDef(@"status",@"draft"),
                             dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                             strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // MatchCandidate
    NSEntityDescription *candidate = [[NSEntityDescription alloc] init];
    candidate.name = @"MatchCandidate"; candidate.managedObjectClassName = @"CMMatchCandidate";
    candidate.properties = @[strAttr(@"candidateId",NO), strAttr(@"tenantId",NO), strAttr(@"itineraryId",NO),
                             strAttr(@"orderId",NO), dblAttr(@"score"), dblAttr(@"detourMiles"),
                             dblAttr(@"timeOverlapMinutes"), dblAttr(@"capacityRisk"),
                             transAttr(@"explanationComponents"), i32Attr(@"rankPosition"),
                             dateAttr(@"computedAt",YES), boolAttr(@"stale"),
                             dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                             strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // RubricTemplate
    NSEntityDescription *rubric = [[NSEntityDescription alloc] init];
    rubric.name = @"RubricTemplate"; rubric.managedObjectClassName = @"CMRubricTemplate";
    rubric.properties = @[strAttr(@"rubricId",NO), strAttr(@"tenantId",NO), strAttr(@"name",NO),
                          boolAttr(@"active"), i64Attr(@"rubricVersion",1), transAttr(@"items"),
                          dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                          strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // DeliveryScorecard
    NSEntityDescription *scorecard = [[NSEntityDescription alloc] init];
    scorecard.name = @"DeliveryScorecard"; scorecard.managedObjectClassName = @"CMDeliveryScorecard";
    scorecard.properties = @[strAttr(@"scorecardId",NO), strAttr(@"tenantId",NO), strAttr(@"orderId",NO),
                             strAttr(@"courierId",NO), strAttr(@"rubricId",NO), i64Attr(@"rubricVersion",1),
                             strAttr(@"supersedesScorecardId",YES), transAttr(@"automatedResults"),
                             transAttr(@"manualResults"), dblAttr(@"totalPoints"), dblAttr(@"maxPoints"),
                             dateAttr(@"finalizedAt",YES), strAttr(@"finalizedBy",YES),
                             dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                             strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // Dispute
    NSEntityDescription *dispute = [[NSEntityDescription alloc] init];
    dispute.name = @"Dispute"; dispute.managedObjectClassName = @"CMDispute";
    dispute.properties = @[strAttr(@"disputeId",NO), strAttr(@"tenantId",NO), strAttr(@"orderId",NO),
                           strAttr(@"openedBy",NO), dateAttr(@"openedAt",NO), strAttr(@"reason",NO),
                           strAttr(@"reasonCategory",YES), strAttrDef(@"status",@"open"),
                           strAttr(@"reviewerId",YES), strAttr(@"resolution",YES), dateAttr(@"closedAt",YES),
                           dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                           strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // Appeal
    NSEntityDescription *appeal = [[NSEntityDescription alloc] init];
    appeal.name = @"Appeal"; appeal.managedObjectClassName = @"CMAppeal";
    appeal.properties = @[strAttr(@"appealId",NO), strAttr(@"tenantId",NO), strAttr(@"scorecardId",NO),
                          strAttr(@"disputeId",YES), strAttr(@"reason",NO), strAttr(@"openedBy",NO),
                          dateAttr(@"openedAt",NO), strAttr(@"assignedReviewerId",YES),
                          transAttr(@"beforeScoreSnapshotJSON"), transAttr(@"afterScoreSnapshotJSON"),
                          strAttr(@"decision",YES), strAttr(@"decidedBy",YES), dateAttr(@"decidedAt",YES),
                          strAttr(@"decisionNotes",YES), boolAttr(@"monetaryImpact"),
                          strAttr(@"auditChainHead",YES),
                          dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                          strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // NotificationItem
    NSEntityDescription *notification = [[NSEntityDescription alloc] init];
    notification.name = @"NotificationItem"; notification.managedObjectClassName = @"CMNotificationItem";
    notification.properties = @[strAttr(@"notificationId",NO), strAttr(@"tenantId",NO),
                                strAttr(@"subjectEntityType",YES), strAttr(@"subjectEntityId",YES),
                                strAttr(@"templateKey",NO), transAttr(@"payloadJSON"),
                                strAttr(@"renderedTitle",YES), strAttr(@"renderedBody",YES),
                                strAttr(@"recipientUserId",NO), strAttrDef(@"status",@"active"),
                                transAttr(@"childIds"), strAttr(@"rateLimitBucket",YES),
                                dateAttr(@"createdAt",NO), dateAttr(@"readAt",YES), dateAttr(@"ackedAt",YES),
                                dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                                strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // AuditEntry
    NSEntityDescription *auditEntry = [[NSEntityDescription alloc] init];
    auditEntry.name = @"AuditEntry"; auditEntry.managedObjectClassName = @"CMAuditEntry";
    auditEntry.properties = @[strAttr(@"entryId",NO), strAttr(@"tenantId",NO), strAttr(@"actorUserId",NO),
                              strAttr(@"actorRole",NO), strAttr(@"action",NO),
                              strAttr(@"targetType",YES), strAttr(@"targetId",YES),
                              transAttr(@"beforeJSON"), transAttr(@"afterJSON"), strAttr(@"reason",YES),
                              dateAttr(@"createdAt",NO),
                              binAttr(@"prevHash"), binAttr(@"entryHash")];
    // NOTE: AuditEntry intentionally has NO deletedAt — it is append-only.

    // LoginHistory
    NSEntityDescription *loginHistory = [[NSEntityDescription alloc] init];
    loginHistory.name = @"LoginHistory"; loginHistory.managedObjectClassName = @"CMLoginHistory";
    loginHistory.properties = @[strAttr(@"entryId",NO), strAttr(@"userId",NO), strAttr(@"tenantId",NO),
                                strAttr(@"deviceModel",YES), strAttr(@"osVersion",YES),
                                strAttr(@"appVersion",YES), dateAttr(@"loggedInAt",NO),
                                dateAttr(@"loggedOutAt",YES), strAttr(@"outcome",NO),
                                dateAttr(@"createdAt",NO), dateAttr(@"updatedAt",NO), dateAttr(@"deletedAt",YES),
                                strAttr(@"createdBy",YES), strAttr(@"updatedBy",YES), i64Attr(@"version",1)];

    // Work entities (sidecar store)
    NSEntityDescription *workAttachExp = [[NSEntityDescription alloc] init];
    workAttachExp.name = @"WorkAttachmentExpiry"; workAttachExp.managedObjectClassName = @"CMWorkAttachmentExpiry";
    workAttachExp.properties = @[strAttr(@"attachmentId",NO), strAttr(@"tenantId",NO),
                                 strAttr(@"storagePath",NO), dateAttr(@"expiresAt",NO)];

    NSEntityDescription *workNotifExp = [[NSEntityDescription alloc] init];
    workNotifExp.name = @"WorkNotificationExpiry"; workNotifExp.managedObjectClassName = @"CMWorkNotificationExpiry";
    workNotifExp.properties = @[strAttr(@"notificationId",NO), strAttr(@"tenantId",NO),
                                dateAttr(@"expiresAt",NO)];

    NSEntityDescription *workAuditCursor = [[NSEntityDescription alloc] init];
    workAuditCursor.name = @"WorkAuditCursor"; workAuditCursor.managedObjectClassName = @"CMWorkAuditCursor";
    workAuditCursor.properties = @[strAttr(@"tenantId",NO), strAttr(@"lastVerifiedEntryId",YES),
                                   dateAttr(@"lastVerifiedAt",YES)];

    model.entities = @[tenant, userAccount, order, itinerary, candidate, rubric, scorecard,
                       dispute, appeal, notification, auditEntry, loginHistory,
                       workAttachExp, workNotifExp, workAuditCursor];
    return model;
}

#pragma mark - Setup / Teardown

- (void)setUp {
    [super setUp];

    // Register value transformers needed by the model.
    [CMEncryptedValueTransformer registerTransformer];
    [CMAddressTransformer registerTransformers];

    // Try to load the model from .momd first, fall back to programmatic model.
    NSManagedObjectModel *model = nil;
    for (NSBundle *bundle in @[[NSBundle mainBundle], [NSBundle bundleForClass:[self class]]]) {
        NSURL *modelURL = [bundle URLForResource:@"CourierMatch" withExtension:@"momd"];
        if (modelURL) {
            model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
            if (model) break;
        }
    }
    if (!model) {
        model = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle],
                                                                [NSBundle bundleForClass:[self class]]]];
    }
    if (!model) {
        model = [[self class] buildProgrammaticModel];
    }
    XCTAssertNotNil(model, @"Failed to load CourierMatch managed object model");

    self.testContainer = [[NSPersistentContainer alloc] initWithName:@"CourierMatch"
                                                 managedObjectModel:model];

    // Single in-memory store (configurations may not be defined in programmatic model).
    NSPersistentStoreDescription *desc = [[NSPersistentStoreDescription alloc] init];
    desc.type = NSInMemoryStoreType;
    desc.shouldAddStoreAsynchronously = NO;

    self.testContainer.persistentStoreDescriptions = @[desc];

    __block NSError *loadError = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [self.testContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDesc,
                                                                     NSError *error) {
        loadError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    XCTAssertNil(loadError, @"Failed to load in-memory stores: %@", loadError);

    self.testContext = self.testContainer.viewContext;
    self.testContext.mergePolicy = [[NSMergePolicy alloc] initWithMergeType:NSOverwriteMergePolicyType];

    // Seed the test tenant.
    [self seedTenant];

    // Seed test users.
    [self seedUsers];

    // Configure CMTenantContext with the courier user by default.
    [self switchToUser:self.courierUser];

    // Configure CMCoreDataStack.shared to use our in-memory container so that
    // production singletons (CMAuthService, CMAuditService, etc.) that call
    // [CMCoreDataStack shared].viewContext / performBackgroundTask work correctly
    // in tests.
#ifdef DEBUG
    [CMCoreDataStack resetSharedForTesting];
    // Point the shared stack's container directly at our test container,
    // so all services see the same in-memory store with seeded data.
    CMCoreDataStack *shared = [CMCoreDataStack shared];
    [shared setValue:self.testContainer forKey:@"container"];
    [shared setValue:@(YES) forKey:@"isLoaded"];
#endif
}

- (void)tearDown {
    // Clear tenant context.
    [[CMTenantContext shared] clear];

    // Disconnect the shared stack from our test container.
#ifdef DEBUG
    [CMCoreDataStack resetSharedForTesting];
#endif

    // Reset the context.
    if (self.testContext) {
        [self.testContext reset];
    }
    self.testContext = nil;
    self.testContainer = nil;

    self.testTenant = nil;
    self.courierUser = nil;
    self.dispatcherUser = nil;
    self.reviewerUser = nil;
    self.csUser = nil;
    self.financeUser = nil;
    self.adminUser = nil;

    [super tearDown];
}

#pragma mark - Seeding

- (void)seedTenant {
    CMTenant *tenant = [NSEntityDescription insertNewObjectForEntityForName:@"Tenant"
                                                     inManagedObjectContext:self.testContext];
    tenant.tenantId = kTestTenantId;
    tenant.name = kTestTenantName;
    tenant.status = CMTenantStatusActive;
    tenant.configJSON = @{};
    tenant.createdAt = [NSDate date];
    tenant.updatedAt = [NSDate date];
    tenant.version = 1;
    self.testTenant = tenant;
    [self saveContext];
}

- (void)seedUsers {
    self.courierUser    = [self createUserWithId:@"user-courier"    username:@"courier"    role:CMUserRoleCourier];
    self.dispatcherUser = [self createUserWithId:@"user-dispatcher" username:@"dispatcher" role:CMUserRoleDispatcher];
    self.reviewerUser   = [self createUserWithId:@"user-reviewer"   username:@"reviewer"   role:CMUserRoleReviewer];
    self.csUser         = [self createUserWithId:@"user-cs"         username:@"cs"         role:CMUserRoleCustomerService];
    self.financeUser    = [self createUserWithId:@"user-finance"    username:@"finance"    role:CMUserRoleFinance];
    self.adminUser      = [self createUserWithId:@"user-admin"      username:@"admin"      role:CMUserRoleAdmin];
    [self saveContext];
}

- (CMUserAccount *)createUserWithId:(NSString *)userId
                           username:(NSString *)username
                               role:(NSString *)role {
    CMUserAccount *user = [NSEntityDescription insertNewObjectForEntityForName:@"UserAccount"
                                                        inManagedObjectContext:self.testContext];
    user.userId = userId;
    user.tenantId = kTestTenantId;
    user.username = username;
    user.displayName = [username capitalizedString];
    user.role = role;
    user.status = CMUserStatusActive;
    user.failedAttempts = 0;
    user.biometricEnabled = NO;
    user.createdAt = [NSDate date];
    user.updatedAt = [NSDate date];
    user.version = 1;
    return user;
}

#pragma mark - Convenience IDs

- (NSString *)testTenantId {
    return kTestTenantId;
}

- (NSString *)courierUserId {
    return self.courierUser.userId;
}

#pragma mark - Convenience Insert Methods

- (CMOrder *)insertTestOrder:(NSString *)orderId {
    CMOrder *order = [NSEntityDescription insertNewObjectForEntityForName:@"Order"
                                                   inManagedObjectContext:self.testContext];
    order.orderId = orderId;
    order.tenantId = kTestTenantId;
    order.externalOrderRef = [NSString stringWithFormat:@"EXT-%@", orderId];
    order.status = CMOrderStatusNew;
    order.parcelVolumeL = 10.0;
    order.parcelWeightKg = 5.0;
    order.createdAt = [NSDate date];
    order.updatedAt = [NSDate date];
    order.version = 1;
    return order;
}

- (CMItinerary *)insertTestItinerary:(NSString *)itineraryId {
    CMItinerary *itin = [NSEntityDescription insertNewObjectForEntityForName:@"Itinerary"
                                                       inManagedObjectContext:self.testContext];
    itin.itineraryId = itineraryId;
    itin.tenantId = kTestTenantId;
    itin.courierId = self.courierUser.userId;
    itin.vehicleType = CMVehicleTypeCar;
    itin.vehicleCapacityVolumeL = 500.0;
    itin.vehicleCapacityWeightKg = 200.0;
    itin.status = CMItineraryStatusActive;
    itin.createdAt = [NSDate date];
    itin.updatedAt = [NSDate date];
    itin.version = 1;
    return itin;
}

- (CMRubricTemplate *)insertTestRubric:(NSString *)rubricId {
    CMRubricTemplate *rubric = [NSEntityDescription insertNewObjectForEntityForName:@"RubricTemplate"
                                                              inManagedObjectContext:self.testContext];
    rubric.rubricId = rubricId;
    rubric.tenantId = kTestTenantId;
    rubric.name = @"Test Rubric";
    rubric.active = YES;
    rubric.rubricVersion = 1;
    rubric.items = @[
        @{
            @"itemKey": @"on_time",
            @"label": @"On-Time Delivery",
            @"mode": @"automatic",
            @"maxPoints": @(25),
            @"autoEvaluator": @"on_time_within_10min"
        },
        @{
            @"itemKey": @"photo_attached",
            @"label": @"Photo Attached",
            @"mode": @"automatic",
            @"maxPoints": @(25),
            @"autoEvaluator": @"photo_attached"
        },
        @{
            @"itemKey": @"customer_satisfaction",
            @"label": @"Customer Satisfaction",
            @"mode": @"manual",
            @"maxPoints": @(25),
            @"instructions": @"Rate overall customer interaction"
        },
        @{
            @"itemKey": @"package_handling",
            @"label": @"Package Handling",
            @"mode": @"manual",
            @"maxPoints": @(25),
            @"instructions": @"Rate care of package during delivery"
        }
    ];
    rubric.createdAt = [NSDate date];
    rubric.updatedAt = [NSDate date];
    rubric.version = 1;
    return rubric;
}

#pragma mark - Helpers

- (CMAddress *)addressWithLat:(double)lat
                          lng:(double)lng
                          zip:(NSString *)zip
                         city:(NSString *)city {
    CMAddress *addr = [[CMAddress alloc] init];
    addr.lat = lat;
    addr.lng = lng;
    addr.zip = zip ?: @"10001";
    addr.city = city ?: @"Test City";
    addr.stateAbbr = @"NY";
    addr.line1 = @"123 Test St";
    return addr;
}

- (void)switchToUser:(CMUserAccount *)user {
    [[CMTenantContext shared] setUserId:user.userId
                               tenantId:user.tenantId
                                   role:user.role];
}

- (BOOL)saveContext {
    NSError *error = nil;
    if (self.testContext.hasChanges) {
        BOOL saved = [self.testContext save:&error];
        XCTAssertTrue(saved, @"Failed to save test context: %@", error);
        return saved;
    }
    return YES;
}

@end
