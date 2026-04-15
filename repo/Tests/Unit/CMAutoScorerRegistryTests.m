//
//  CMAutoScorerRegistryTests.m
//  CourierMatch Unit Tests
//
//  Covers CMAutoScorerRegistry: built-in scorer registration, custom
//  scorer registration, overwrite, lookup, and allKeys.
//

#import <XCTest/XCTest.h>
#import "CMAutoScorerRegistry.h"
#import "CMAutoScorerProtocol.h"
#import "CMAutoScorer_OnTime.h"
#import "CMAutoScorer_PhotoAttached.h"
#import "CMAutoScorer_SignatureCaptured.h"

// ---------------------------------------------------------------------------
// Minimal stub scorer used for custom-registration tests.
// ---------------------------------------------------------------------------
@interface CMStubAutoScorer : NSObject <CMAutoScorerProtocol>
@end

@implementation CMStubAutoScorer
- (NSDictionary *)evaluateForOrder:(id)order
                       attachments:(NSArray *)attachments
                             error:(NSError **)error {
    return @{CMAutoScorerResultPointsKey: @(0.5)};
}
@end

// ---------------------------------------------------------------------------
@interface CMAutoScorerRegistryTests : XCTestCase
@end

@implementation CMAutoScorerRegistryTests

#pragma mark - Singleton

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMAutoScorerRegistry shared], [CMAutoScorerRegistry shared],
                   @"shared must return the same instance on every call");
}

- (void)testSharedIsNotNil {
    XCTAssertNotNil([CMAutoScorerRegistry shared]);
}

#pragma mark - Built-in Scorers Registered on First Access

- (void)testBuiltInOnTimeScorerIsRegistered {
    id<CMAutoScorerProtocol> scorer = [[CMAutoScorerRegistry shared]
        scorerForKey:@"on_time_within_10min"];
    XCTAssertNotNil(scorer, @"on_time_within_10min must be registered");
    XCTAssertTrue([scorer isKindOfClass:[CMAutoScorer_OnTime class]],
                  @"Scorer must be CMAutoScorer_OnTime");
}

- (void)testBuiltInPhotoAttachedScorerIsRegistered {
    id<CMAutoScorerProtocol> scorer = [[CMAutoScorerRegistry shared]
        scorerForKey:@"photo_attached"];
    XCTAssertNotNil(scorer, @"photo_attached must be registered");
    XCTAssertTrue([scorer isKindOfClass:[CMAutoScorer_PhotoAttached class]]);
}

- (void)testBuiltInSignatureCapturedScorerIsRegistered {
    id<CMAutoScorerProtocol> scorer = [[CMAutoScorerRegistry shared]
        scorerForKey:@"signature_captured"];
    XCTAssertNotNil(scorer, @"signature_captured must be registered");
    XCTAssertTrue([scorer isKindOfClass:[CMAutoScorer_SignatureCaptured class]]);
}

#pragma mark - allKeys

- (void)testAllKeysIsNotNil {
    XCTAssertNotNil([[CMAutoScorerRegistry shared] allKeys]);
}

- (void)testAllKeysContainsAtLeastThreeBuiltIns {
    NSArray *keys = [[CMAutoScorerRegistry shared] allKeys];
    XCTAssertGreaterThanOrEqual(keys.count, 3u,
                                @"Registry must have at least 3 built-in evaluator keys");
}

- (void)testAllKeysContainsOnTimeKey {
    XCTAssertTrue([[[CMAutoScorerRegistry shared] allKeys]
                   containsObject:@"on_time_within_10min"]);
}

- (void)testAllKeysContainsPhotoAttachedKey {
    XCTAssertTrue([[[CMAutoScorerRegistry shared] allKeys]
                   containsObject:@"photo_attached"]);
}

- (void)testAllKeysContainsSignatureCapturedKey {
    XCTAssertTrue([[[CMAutoScorerRegistry shared] allKeys]
                   containsObject:@"signature_captured"]);
}

#pragma mark - scorerForKey: Unknown Key

- (void)testScorerForUnknownKey_ReturnsNil {
    id<CMAutoScorerProtocol> scorer = [[CMAutoScorerRegistry shared]
        scorerForKey:@"nonexistent_key_xyz_abc"];
    XCTAssertNil(scorer, @"Unknown evaluator key must return nil");
}

#pragma mark - Custom Registration

- (void)testRegisterCustomScorer_CanBeRetrieved {
    NSString *key = [NSString stringWithFormat:@"custom_%@", [[NSUUID UUID] UUIDString]];
    CMStubAutoScorer *stub = [[CMStubAutoScorer alloc] init];
    [[CMAutoScorerRegistry shared] registerScorer:stub forKey:key];

    id<CMAutoScorerProtocol> retrieved = [[CMAutoScorerRegistry shared] scorerForKey:key];
    XCTAssertEqual(retrieved, stub, @"Registered custom scorer must be retrievable by key");
}

- (void)testRegisterCustomScorer_OverwritesExisting {
    NSString *key = [NSString stringWithFormat:@"overwrite_%@", [[NSUUID UUID] UUIDString]];
    CMStubAutoScorer *first  = [[CMStubAutoScorer alloc] init];
    CMStubAutoScorer *second = [[CMStubAutoScorer alloc] init];

    [[CMAutoScorerRegistry shared] registerScorer:first  forKey:key];
    [[CMAutoScorerRegistry shared] registerScorer:second forKey:key];

    id<CMAutoScorerProtocol> retrieved = [[CMAutoScorerRegistry shared] scorerForKey:key];
    XCTAssertEqual(retrieved, second,
                   @"Second registerScorer:forKey: must overwrite the first");
}

- (void)testRegisterCustomScorer_AppearsInAllKeys {
    NSString *key = [NSString stringWithFormat:@"allkeys_%@", [[NSUUID UUID] UUIDString]];
    CMStubAutoScorer *stub = [[CMStubAutoScorer alloc] init];
    [[CMAutoScorerRegistry shared] registerScorer:stub forKey:key];

    NSArray *keys = [[CMAutoScorerRegistry shared] allKeys];
    XCTAssertTrue([keys containsObject:key],
                  @"Newly registered key must appear in allKeys");
}

@end
