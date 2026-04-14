//
//  CMSaveWithVersionCheckPolicyTests.m
//  CourierMatch
//
//  Unit tests for CMSaveWithVersionCheckPolicy — optimistic locking + field
//  merge per questions.md Q9.
//
//  Uses an in-memory Core Data stack with a minimal test entity (TestVersioned)
//  that has the attributes needed: version, fieldA, fieldB, fieldC.
//

#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import "CMSaveWithVersionCheckPolicy.h"
#import "NSManagedObjectContext+CMHelpers.h"

#pragma mark - Minimal test entity

/// A trivial NSManagedObject subclass with three string fields and a version.
/// We use @dynamic so Core Data provides the storage.
@interface CMTestVersionedObject : NSManagedObject
@property (nonatomic, assign) int64_t version;
@property (nonatomic, copy)   NSString *fieldA;
@property (nonatomic, copy)   NSString *fieldB;
@property (nonatomic, copy)   NSString *fieldC;
@end

@implementation CMTestVersionedObject
@dynamic version, fieldA, fieldB, fieldC;
@end

#pragma mark - Test case

@interface CMSaveWithVersionCheckPolicyTests : XCTestCase
@property (nonatomic, strong) NSPersistentContainer *container;
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMSaveWithVersionCheckPolicyTests

#pragma mark - In-memory Core Data setup

- (NSManagedObjectModel *)testModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = @"TestVersioned";
    entity.managedObjectClassName = @"CMTestVersionedObject";

    NSMutableArray<NSAttributeDescription *> *attrs = [NSMutableArray array];

    // version — Integer 64
    {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = @"version";
        a.attributeType = NSInteger64AttributeType;
        a.defaultValue = @(1);
        a.optional = NO;
        [attrs addObject:a];
    }
    // fieldA, fieldB, fieldC — String
    for (NSString *name in @[@"fieldA", @"fieldB", @"fieldC"]) {
        NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
        a.name = name;
        a.attributeType = NSStringAttributeType;
        a.optional = YES;
        [attrs addObject:a];
    }

    entity.properties = attrs;
    model.entities = @[entity];
    return model;
}

- (CMTestVersionedObject *)insertObjectWithA:(NSString *)a B:(NSString *)b C:(NSString *)c {
    CMTestVersionedObject *obj =
        [NSEntityDescription insertNewObjectForEntityForName:@"TestVersioned"
                                      inManagedObjectContext:self.context];
    obj.fieldA = a;
    obj.fieldB = b;
    obj.fieldC = c;
    obj.version = 1;
    NSError *err = nil;
    XCTAssertTrue([self.context save:&err], @"Initial save failed: %@", err);
    return obj;
}

- (void)setUp {
    [super setUp];
    NSManagedObjectModel *model = [self testModel];
    self.container = [[NSPersistentContainer alloc] initWithName:@"TestVersionCheckStore"
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

#pragma mark - Fast path: matching version

- (void)testSave_MatchingVersion_SucceedsAndBumpsVersion {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];
    int64_t baseVersion = obj.version; // 1

    NSError *err = nil;
    NSArray *merged = nil;
    NSArray *conflict = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a2"}
                             toObject:obj
                             baseVersion:baseVersion
                             resolver:nil
                             mergedFields:&merged
                             conflictFields:&conflict
                             error:&err];

    XCTAssertEqual(outcome, CMSaveOutcomeSaved);
    XCTAssertNil(err);
    XCTAssertEqual(obj.version, baseVersion + 1);
    XCTAssertEqualObjects(obj.fieldA, @"a2");
    XCTAssertEqualObjects(merged, @[]);
    XCTAssertEqualObjects(conflict, @[]);
}

- (void)testSave_MatchingVersion_MultiplFields {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];

    NSError *err = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a2", @"fieldB": @"b2"}
                             toObject:obj
                             baseVersion:1
                             resolver:nil
                             mergedFields:NULL
                             conflictFields:NULL
                             error:&err];

    XCTAssertEqual(outcome, CMSaveOutcomeSaved);
    XCTAssertEqualObjects(obj.fieldA, @"a2");
    XCTAssertEqualObjects(obj.fieldB, @"b2");
    XCTAssertEqual(obj.version, 2);
}

#pragma mark - Slow path: mismatched version

- (void)testSave_MismatchedVersion_TriggersConflictPath {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];

    // Simulate another writer bumping the version.
    obj.version = 2;
    [self.context save:nil];

    NSError *err = nil;
    NSArray *merged = nil;
    NSArray *conflict = nil;
    // Caller thinks the base version is still 1.
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a-mine"}
                             toObject:obj
                             baseVersion:1
                             resolver:^CMFieldMergeResolution(NSString *field, id mine, id theirs) {
                                 return CMFieldMergeResolutionKeepMine;
                             }
                             mergedFields:&merged
                             conflictFields:&conflict
                             error:&err];

    // The field value on disk differs from what we want to write, so the
    // resolver is consulted and the outcome is ResolvedAndSaved.
    XCTAssertTrue(outcome == CMSaveOutcomeResolvedAndSaved ||
                  outcome == CMSaveOutcomeAutoMerged,
                  @"Mismatched version must enter the conflict path; got %ld", (long)outcome);
    XCTAssertNil(err);
    // Version must be bumped from current (2) to 3.
    XCTAssertEqual(obj.version, 3);
}

#pragma mark - Disjoint field changes -> auto-merge

- (void)testSave_DisjointFields_AutoMerge {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];

    // Simulate another writer changing fieldB and bumping version.
    obj.fieldB = @"b-theirs";
    obj.version = 2;
    [self.context save:nil];

    NSError *err = nil;
    NSArray *merged = nil;
    NSArray *conflict = nil;
    // We want to change fieldA (which "they" did not touch and is still "a1"
    // on disk). Since refreshObject:mergeChanges:NO re-reads, the object shows
    // fieldA="a1" (same as originally) and fieldB="b-theirs".
    // Our change: fieldA -> "a-mine" (disk has "a1", so different) -> auto-merged.
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a-mine"}
                             toObject:obj
                             baseVersion:1
                             resolver:nil
                             mergedFields:&merged
                             conflictFields:&conflict
                             error:&err];

    XCTAssertEqual(outcome, CMSaveOutcomeAutoMerged);
    XCTAssertNil(err);
    XCTAssertEqualObjects(obj.fieldA, @"a-mine");
    // fieldB should still be "b-theirs" (we did not touch it).
    XCTAssertEqualObjects(obj.fieldB, @"b-theirs");
    // merged should include fieldA.
    XCTAssertTrue([merged containsObject:@"fieldA"]);
    XCTAssertEqual(conflict.count, 0u);
}

#pragma mark - Overlapping field changes -> resolver consulted

- (void)testSave_OverlappingFields_InvokesResolver_KeepMine {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];

    // Simulate another writer changing fieldA.
    obj.fieldA = @"a-theirs";
    obj.version = 2;
    [self.context save:nil];

    __block NSString *resolvedField = nil;
    NSError *err = nil;
    NSArray *merged = nil;
    NSArray *conflict = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a-mine"}
                             toObject:obj
                             baseVersion:1
                             resolver:^CMFieldMergeResolution(NSString *field, id mine, id theirs) {
                                 resolvedField = field;
                                 return CMFieldMergeResolutionKeepMine;
                             }
                             mergedFields:&merged
                             conflictFields:&conflict
                             error:&err];

    XCTAssertEqual(outcome, CMSaveOutcomeResolvedAndSaved);
    XCTAssertEqualObjects(resolvedField, @"fieldA");
    XCTAssertEqualObjects(obj.fieldA, @"a-mine");
    XCTAssertTrue([conflict containsObject:@"fieldA"]);
}

- (void)testSave_OverlappingFields_InvokesResolver_KeepTheirs {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];

    // Simulate another writer changing fieldA.
    obj.fieldA = @"a-theirs";
    obj.version = 2;
    [self.context save:nil];

    NSError *err = nil;
    NSArray *conflict = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a-mine"}
                             toObject:obj
                             baseVersion:1
                             resolver:^CMFieldMergeResolution(NSString *field, id mine, id theirs) {
                                 return CMFieldMergeResolutionKeepTheirs;
                             }
                             mergedFields:NULL
                             conflictFields:&conflict
                             error:&err];

    XCTAssertEqual(outcome, CMSaveOutcomeResolvedAndSaved);
    // "Keep theirs" means the on-disk value survives.
    XCTAssertEqualObjects(obj.fieldA, @"a-theirs");
    XCTAssertTrue([conflict containsObject:@"fieldA"]);
}

#pragma mark - Nil / missing args

- (void)testSave_NilObject_ReturnsFailed {
    NSError *err = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"x"}
                             toObject:nil
                             baseVersion:1
                             resolver:nil
                             mergedFields:NULL
                             conflictFields:NULL
                             error:&err];
    XCTAssertEqual(outcome, CMSaveOutcomeFailed);
    XCTAssertNotNil(err);
}

- (void)testSave_NilChanges_ReturnsFailed {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a" B:@"b" C:@"c"];
    NSError *err = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:nil
                             toObject:obj
                             baseVersion:1
                             resolver:nil
                             mergedFields:NULL
                             conflictFields:NULL
                             error:&err];
    XCTAssertEqual(outcome, CMSaveOutcomeFailed);
    XCTAssertNotNil(err);
}

#pragma mark - Version bumps correctly on conflict path

- (void)testSave_ConflictPath_VersionBumpsFromCurrent {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];
    // Bump version to 5 on disk.
    obj.version = 5;
    [self.context save:nil];

    NSError *err = nil;
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a-mine"}
                             toObject:obj
                             baseVersion:1
                             resolver:^CMFieldMergeResolution(NSString *f, id m, id t) {
                                 return CMFieldMergeResolutionKeepMine;
                             }
                             mergedFields:NULL
                             conflictFields:NULL
                             error:&err];

    XCTAssertTrue(outcome != CMSaveOutcomeFailed);
    // Should bump from currentV (5) to 6.
    XCTAssertEqual(obj.version, 6);
}

#pragma mark - Same-value changes are not conflicts

- (void)testSave_SameValueChange_IsNotConflict {
    CMTestVersionedObject *obj = [self insertObjectWithA:@"a1" B:@"b1" C:@"c1"];
    obj.version = 2;
    [self.context save:nil];

    NSError *err = nil;
    NSArray *conflict = nil;
    NSArray *merged = nil;
    // We "change" fieldA to the same value that is already on disk.
    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:@{@"fieldA": @"a1"}
                             toObject:obj
                             baseVersion:1
                             resolver:nil
                             mergedFields:&merged
                             conflictFields:&conflict
                             error:&err];

    // No actual field conflict; both merged and conflict should be empty.
    XCTAssertTrue(outcome == CMSaveOutcomeAutoMerged || outcome == CMSaveOutcomeSaved,
                  @"Same-value 'change' should auto-merge or be treated as saved");
    XCTAssertEqual(conflict.count, 0u);
}

@end
