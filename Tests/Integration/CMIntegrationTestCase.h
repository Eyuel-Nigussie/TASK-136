//
//  CMIntegrationTestCase.h
//  CourierMatch Integration Tests
//
//  Base class for integration tests. Provides an in-memory Core Data stack,
//  test tenant, test users (courier, dispatcher, reviewer, cs, finance, admin),
//  and convenience methods for inserting test entities.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>

@class CMTenant;
@class CMUserAccount;
@class CMOrder;
@class CMItinerary;
@class CMRubricTemplate;
@class CMAddress;

NS_ASSUME_NONNULL_BEGIN

@interface CMIntegrationTestCase : XCTestCase

#pragma mark - Core Data

/// In-memory persistent container loaded in -setUp.
@property (nonatomic, strong) NSPersistentContainer *testContainer;

/// Main-queue context for assertions and reads.
@property (nonatomic, strong) NSManagedObjectContext *testContext;

#pragma mark - Test Tenant & Users

@property (nonatomic, strong) CMTenant *testTenant;
@property (nonatomic, strong) CMUserAccount *courierUser;
@property (nonatomic, strong) CMUserAccount *dispatcherUser;
@property (nonatomic, strong) CMUserAccount *reviewerUser;
@property (nonatomic, strong) CMUserAccount *csUser;
@property (nonatomic, strong) CMUserAccount *financeUser;
@property (nonatomic, strong) CMUserAccount *adminUser;

#pragma mark - Convenience IDs

@property (nonatomic, copy, readonly) NSString *testTenantId;
@property (nonatomic, copy, readonly) NSString *courierUserId;

#pragma mark - Convenience Insert Methods

/// Inserts a test order with the given orderId into the test context.
/// The order is scoped to the test tenant and set to status "new".
- (CMOrder *)insertTestOrder:(NSString *)orderId;

/// Inserts a test itinerary with the given itineraryId into the test context.
/// The itinerary is scoped to the test tenant and courier user.
- (CMItinerary *)insertTestItinerary:(NSString *)itineraryId;

/// Inserts an active rubric template with the given rubricId into the test context.
- (CMRubricTemplate *)insertTestRubric:(NSString *)rubricId;

#pragma mark - Helpers

/// Creates a CMAddress value object from the given parameters.
- (CMAddress *)addressWithLat:(double)lat
                          lng:(double)lng
                          zip:(nullable NSString *)zip
                         city:(nullable NSString *)city;

/// Switches the CMTenantContext to the given user.
- (void)switchToUser:(CMUserAccount *)user;

/// Saves the test context and fails the test on error.
- (BOOL)saveContext;

@end

NS_ASSUME_NONNULL_END
