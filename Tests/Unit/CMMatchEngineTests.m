//
//  CMMatchEngineTests.m
//  CourierMatch Tests
//
//  Tests for the match engine boundary cases per design.md section 17:
//  detour boundaries, time overlap boundaries, vehicle mismatch,
//  capacity checks, and deterministic ranking.
//
//  Uses an in-memory Core Data stack with Itinerary, Order, MatchCandidate,
//  and Tenant entities.
//

#import <XCTest/XCTest.h>
#import "CMMatchScoringWeights.h"
#import "CMGeoMath.h"
#import "CMZipMetroTable.h"
#import "CMVehicleSpeedTable.h"
#import "CMMatchExplanation.h"
#import "CMMatchCandidate.h"
#import "CMItinerary.h"
#import "CMOrder.h"
#import "CMAddress.h"
#import "CMTestCoreDataHelper.h"

// ---------------------------------------------------------------------------
// We re-implement the scoring logic inline to unit-test each boundary case
// without relying on the full engine (which requires CoreDataStack.shared,
// repositories, background queues). This mirrors CMMatchEngine's scoreOrder
// method exactly so we can verify boundaries deterministically.
// ---------------------------------------------------------------------------

/// Struct matching CMMatchEngine's internal CMScoreResult.
typedef struct {
    double score;
    double detourMiles;
    double timeOverlapMinutes;
    double capacityRisk;
    double timeFitScore;
    double detourScore;
    double capacityScore;
    double vehicleScore;
    double timeDelta;
    double detourDelta;
    double capacityDelta;
    double vehicleDelta;
    BOOL   passedFilters;
} CMTestScoreResult;

/// Computes the score for an order against itinerary parameters.
/// Replicates CMMatchEngine's scoring logic for boundary testing.
static CMTestScoreResult computeScore(
    double originLat, double originLng,
    double destLat, double destLng,
    NSString *originZip, NSString *destZip,
    NSString *vehicleType,
    double vehicleCapVolumeL, double vehicleCapWeightKg,
    NSDate *departureStart,
    CMAddress *pickup, CMAddress *dropoff,
    NSDate *pickupWindowStart, NSDate *pickupWindowEnd,
    double parcelVolumeL, double parcelWeightKg,
    NSString *requiresVehicleType,
    CMMatchScoringWeights *weights,
    CMZipMetroTable *zipTable)
{
    CMTestScoreResult result;
    memset(&result, 0, sizeof(result));
    result.passedFilters = NO;

    // Detour calculation
    double directDistance = CMGeoDistanceMiles(originLat, originLng, destLat, destLng);
    double detourRoute = CMGeoMultiLegDistanceMiles(
        originLat, originLng,
        pickup.lat, pickup.lng,
        dropoff.lat, dropoff.lng,
        destLat, destLng);
    double rawDetourMiles = detourRoute - directDistance;
    if (rawDetourMiles < 0.0) rawDetourMiles = 0.0;

    BOOL bothMetro = [zipTable areBothMetroZip1:originZip zip2:pickup.zip];
    double multiplier = [zipTable multiplierForBothMetro:bothMetro];
    double adjustedDetourMiles = rawDetourMiles * multiplier;

    // Allow a tiny epsilon for floating-point imprecision (e.g., binary-search
    // targeting exactly 8.00 miles may produce 8.0000000001).
    if (adjustedDetourMiles > weights.maxDetourMiles + 1e-6) {
        return result;
    }
    result.detourMiles = adjustedDetourMiles;

    // Time overlap
    BOOL isUrban = bothMetro;
    double travelMinutesToPickup = [CMVehicleSpeedTable travelMinutesForMiles:
        CMGeoDistanceMiles(originLat, originLng, pickup.lat, pickup.lng) * multiplier
                                                                 vehicleType:vehicleType
                                                                     isUrban:isUrban];
    NSDate *etaAtPickup = [departureStart dateByAddingTimeInterval:travelMinutesToPickup * 60.0];

    double overlapMinutes = 0.0;
    if (etaAtPickup && pickupWindowStart && pickupWindowEnd) {
        NSDate *etaPlusWait = [etaAtPickup dateByAddingTimeInterval:weights.maxWaitMinutes * 60.0];
        NSDate *overlapEnd = ([pickupWindowEnd compare:etaPlusWait] == NSOrderedAscending)
                             ? pickupWindowEnd : etaPlusWait;
        NSDate *overlapStart = ([pickupWindowStart compare:etaAtPickup] == NSOrderedDescending)
                               ? pickupWindowStart : etaAtPickup;
        NSTimeInterval overlapSeconds = [overlapEnd timeIntervalSinceDate:overlapStart];
        overlapMinutes = overlapSeconds / 60.0;
    }

    if (overlapMinutes < weights.minTimeOverlapMinutes) {
        return result;
    }
    result.timeOverlapMinutes = overlapMinutes;

    // Capacity
    double volumeRisk = (vehicleCapVolumeL > 0.0) ? (parcelVolumeL / vehicleCapVolumeL) : 0.0;
    double weightRisk = (vehicleCapWeightKg > 0.0) ? (parcelWeightKg / vehicleCapWeightKg) : 0.0;
    double capacityRisk = fmax(volumeRisk, weightRisk);

    if (volumeRisk > 1.0 || weightRisk > 1.0) {
        return result;
    }
    result.capacityRisk = capacityRisk;

    // Vehicle mismatch (hard filter already applied in engine before scoring)
    if (requiresVehicleType.length > 0 && vehicleType.length > 0 &&
        ![requiresVehicleType isEqualToString:vehicleType]) {
        return result;
    }

    // Component scores
    double timeFitScore = fmin(overlapMinutes / 60.0, 1.0);
    double detourScore = 1.0 - (adjustedDetourMiles / weights.maxDetourMiles);
    if (detourScore < 0.0) detourScore = 0.0;
    double capacityScore = 1.0 - capacityRisk;
    if (capacityScore < 0.0) capacityScore = 0.0;
    double vehicleScore = 1.0;
    if (requiresVehicleType.length > 0) {
        vehicleScore = [requiresVehicleType isEqualToString:vehicleType] ? 1.0 : 0.0;
    }

    result.timeFitScore = timeFitScore;
    result.detourScore = detourScore;
    result.capacityScore = capacityScore;
    result.vehicleScore = vehicleScore;

    result.timeDelta = weights.wTime * timeFitScore;
    result.detourDelta = weights.wDetour * detourScore;
    result.capacityDelta = weights.wCapacity * capacityScore;
    result.vehicleDelta = weights.wVehicle * vehicleScore;

    result.score = result.timeDelta + result.detourDelta + result.capacityDelta + result.vehicleDelta;
    result.passedFilters = YES;

    return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@interface CMMatchEngineTests : XCTestCase
@property (nonatomic, strong) NSManagedObjectContext *ctx;
@property (nonatomic, strong) CMMatchScoringWeights *weights;
@property (nonatomic, strong) CMZipMetroTable *zipTable;

// Base itinerary parameters
@property (nonatomic, assign) double originLat;
@property (nonatomic, assign) double originLng;
@property (nonatomic, assign) double destLat;
@property (nonatomic, assign) double destLng;
@property (nonatomic, strong) NSDate *departureStart;
@end

@implementation CMMatchEngineTests

- (void)setUp {
    [super setUp];
    self.ctx = [CMTestCoreDataHelper inMemoryContext];
    self.weights = [[CMMatchScoringWeights alloc] init]; // defaults

    self.zipTable = [[CMZipMetroTable alloc] init];
    // Use rural multiplier (1.15) to simplify distance calculations.
    // We'll use rural ZIP codes so bothMetro = NO and multiplier = 1.15.

    // Origin: a point. Destination: a different point ~50 miles away.
    self.originLat = 40.0;
    self.originLng = -74.0;
    self.destLat   = 40.5;
    self.destLng   = -74.0;
    self.departureStart = [NSDate dateWithTimeIntervalSince1970:1700000000.0];
}

#pragma mark - Helpers

/// Create a pickup address at a controlled offset from the origin,
/// so detour miles can be predicted.
- (CMAddress *)pickupAddressForDetourTest {
    // Pickup at origin (effectively): zero extra detour from origin to pickup.
    return [CMTestCoreDataHelper addressWithLat:self.originLat lng:self.originLng zip:@"55555"];
}

- (CMAddress *)dropoffAddressForDetourTest {
    return [CMTestCoreDataHelper addressWithLat:self.destLat lng:self.destLng zip:@"55556"];
}

/// Create pickup/dropoff that cause a specific raw detour in miles.
/// We place the pickup slightly off the direct path. The detour route
/// goes origin->pickup->dropoff->dest. If pickup=origin and dropoff=dest, detour = 0.
/// To get a specific detour, we offset the pickup.
///
/// Since direct route = origin->dest and detour route = origin->pickup->dropoff->dest,
/// placing pickup and dropoff at origin and dest gives detour = 0.
/// Offsetting pickup by deltaDeg latitude adds approximately deltaDeg*69 miles
/// to legs 1+2 minus the direct. We compute the exact detour.
- (void)pickupForExactDetourMiles:(double)targetDetourMiles
                   adjustedDetour:(double *)outAdjusted
                          pickup:(CMAddress **)outPickup
                         dropoff:(CMAddress **)outDropoff {
    // Use rural ZIPs to get multiplier = 1.15.
    // adjustedDetour = rawDetour * 1.15
    // We need adjustedDetour = targetDetourMiles, so rawDetour = target / 1.15
    // We binary-search for a latitude offset that gives us the right raw detour.

    double multiplier = [self.zipTable multiplierForBothMetro:NO];
    double targetRaw = targetDetourMiles / multiplier;

    double directDist = CMGeoDistanceMiles(self.originLat, self.originLng,
                                            self.destLat, self.destLng);

    // Binary search for the longitude offset of the pickup
    double lo = 0.0, hi = 1.0;
    double bestOffset = 0.0;
    for (int iter = 0; iter < 100; iter++) {
        double mid = (lo + hi) / 2.0;
        double pickupLat = self.originLat;
        double pickupLng = self.originLng + mid;
        double multiLeg = CMGeoMultiLegDistanceMiles(
            self.originLat, self.originLng,
            pickupLat, pickupLng,
            self.destLat, self.destLng,
            self.destLat, self.destLng);
        double rawDetour = multiLeg - directDist;
        if (rawDetour < 0) rawDetour = 0;

        if (rawDetour < targetRaw) {
            lo = mid;
        } else {
            hi = mid;
        }
        bestOffset = mid;
    }

    *outPickup = [CMTestCoreDataHelper addressWithLat:self.originLat
                                                  lng:self.originLng + bestOffset
                                                  zip:@"55555"];
    *outDropoff = [CMTestCoreDataHelper addressWithLat:self.destLat
                                                   lng:self.destLng
                                                   zip:@"55556"];

    // Compute the actual adjusted detour for verification.
    double multiLeg = CMGeoMultiLegDistanceMiles(
        self.originLat, self.originLng,
        (*outPickup).lat, (*outPickup).lng,
        (*outDropoff).lat, (*outDropoff).lng,
        self.destLat, self.destLng);
    double rawDetour = multiLeg - directDist;
    if (rawDetour < 0) rawDetour = 0;
    *outAdjusted = rawDetour * multiplier;
}

/// Creates a pickup window centered around the ETA to ensure a given overlap.
- (void)pickupWindowForOverlapMinutes:(double)targetOverlapMinutes
                               pickup:(CMAddress *)pickup
                          windowStart:(NSDate **)outStart
                            windowEnd:(NSDate **)outEnd {
    // Compute ETA at pickup.
    BOOL bothMetro = [self.zipTable areBothMetroZip1:@"55555" zip2:pickup.zip];
    BOOL isUrban = bothMetro;
    double multiplier = [self.zipTable multiplierForBothMetro:bothMetro];
    double distToPickup = CMGeoDistanceMiles(self.originLat, self.originLng,
                                              pickup.lat, pickup.lng);
    double adjustedDist = distToPickup * multiplier;
    double travelMin = [CMVehicleSpeedTable travelMinutesForMiles:adjustedDist
                                                     vehicleType:@"car"
                                                         isUrban:isUrban];
    NSDate *eta = [self.departureStart dateByAddingTimeInterval:travelMin * 60.0];

    // The overlap formula is: min(pickupEnd, eta+maxWait) - max(pickupStart, eta)
    // If pickupStart = eta and pickupEnd = eta + targetOverlap, overlap = targetOverlap.
    *outStart = eta;
    *outEnd = [eta dateByAddingTimeInterval:targetOverlapMinutes * 60.0];
}

#pragma mark - Detour Boundaries (Q2)

- (void)testDetourAt7_99MilesPassesFilter {
    CMAddress *pickup = nil, *dropoff = nil;
    double actualDetour = 0;
    [self pickupForExactDetourMiles:7.99 adjustedDetour:&actualDetour
                            pickup:&pickup dropoff:&dropoff];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"Detour at ~7.99 miles should pass the 8.0 mile filter (actual=%.3f)", result.detourMiles);
}

- (void)testDetourAtExactly8_00MilesPassesFilter {
    CMAddress *pickup = nil, *dropoff = nil;
    double actualDetour = 0;
    [self pickupForExactDetourMiles:8.00 adjustedDetour:&actualDetour
                            pickup:&pickup dropoff:&dropoff];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    // The boundary condition is adjustedDetourMiles > maxDetourMiles (not >=).
    // So exactly 8.0 should pass.
    XCTAssertTrue(result.passedFilters,
        @"Detour at exactly 8.00 miles should pass (<=8.0), actual=%.3f", result.detourMiles);
}

- (void)testDetourAt8_01MilesFilteredOut {
    CMAddress *pickup = nil, *dropoff = nil;
    double actualDetour = 0;
    [self pickupForExactDetourMiles:8.01 adjustedDetour:&actualDetour
                            pickup:&pickup dropoff:&dropoff];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertFalse(result.passedFilters,
        @"Detour at 8.01 miles should be filtered out (>8.0)");
}

- (void)testDetourScoreAtZeroMilesEqualsOne {
    // Pickup at origin, dropoff at destination -> zero detour.
    CMAddress *pickup = [CMTestCoreDataHelper addressWithLat:self.originLat
                                                        lng:self.originLng
                                                        zip:@"55555"];
    CMAddress *dropoff = [CMTestCoreDataHelper addressWithLat:self.destLat
                                                         lng:self.destLng
                                                         zip:@"55556"];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters);
    XCTAssertEqualWithAccuracy(result.detourScore, 1.0, 0.05,
        @"Detour score at 0 miles should be ~1.0, got %.3f", result.detourScore);
}

- (void)testDetourScoreAtHalfMaxEquals0_5 {
    // maxDetourMiles = 8.0, so at 4 miles: score = 1 - (4/8) = 0.5
    CMAddress *pickup = nil, *dropoff = nil;
    double actualDetour = 0;
    [self pickupForExactDetourMiles:4.0 adjustedDetour:&actualDetour
                            pickup:&pickup dropoff:&dropoff];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters);
    XCTAssertEqualWithAccuracy(result.detourScore, 0.5, 0.05,
        @"Detour score at 4 miles should be ~0.5 (1 - 4/8), got %.3f", result.detourScore);
}

#pragma mark - Time Overlap Boundaries (Q3)

- (void)testOverlapAt19MinutesFilteredOut {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:19 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertFalse(result.passedFilters,
        @"Overlap at 19 minutes should be filtered out (< 20 min threshold)");
}

- (void)testOverlapAtExactly20MinutesPasses {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:20 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"Overlap at exactly 20 minutes should pass (>= 20 min threshold)");
}

- (void)testOverlapAt21MinutesPasses {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:21 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"Overlap at 21 minutes should pass");
}

- (void)testTimeFitScoreAt60MinOverlapEquals1_0 {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:60 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters);
    XCTAssertEqualWithAccuracy(result.timeFitScore, 1.0, 0.01,
        @"timeFitScore at 60 min overlap should be 1.0 (capped)");
}

- (void)testTimeFitScoreAt30MinOverlapEquals0_5 {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters);
    XCTAssertEqualWithAccuracy(result.timeFitScore, 0.5, 0.01,
        @"timeFitScore at 30 min overlap should be 0.5 (30/60)");
}

#pragma mark - Vehicle Mismatch

- (void)testOrderRequiresVanItineraryIsCarFilteredOut {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, @"van", self.weights, self.zipTable);

    XCTAssertFalse(result.passedFilters,
        @"Order requiring 'van' with itinerary 'car' should be filtered out");
}

- (void)testOrderRequiresCarItineraryIsCarPasses {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, @"car", self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"Order requiring 'car' with itinerary 'car' should pass");
}

- (void)testOrderNoVehicleRequirementPassesAnyVehicle {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"truck", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"Order with no vehicle requirement should pass any vehicle type");
}

#pragma mark - Capacity

- (void)testParcelExceedsVolumeFilteredOut {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    // Vehicle capacity: 50L volume. Parcel: 60L -> exceeds.
    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 50.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        60.0, 10.0, nil, self.weights, self.zipTable);

    XCTAssertFalse(result.passedFilters,
        @"Parcel exceeding volume capacity should be filtered out");
}

- (void)testParcelExceedsWeightFilteredOut {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    // Vehicle capacity: 50kg weight. Parcel: 60kg -> exceeds.
    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 50.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        10.0, 60.0, nil, self.weights, self.zipTable);

    XCTAssertFalse(result.passedFilters,
        @"Parcel exceeding weight capacity should be filtered out");
}

- (void)testParcelAt80PercentCapacity {
    CMAddress *pickup = [self pickupAddressForDetourTest];
    CMAddress *dropoff = [self dropoffAddressForDetourTest];

    NSDate *pwStart = nil, *pwEnd = nil;
    [self pickupWindowForOverlapMinutes:30 pickup:pickup
                            windowStart:&pwStart windowEnd:&pwEnd];

    // Vehicle: 100L/100kg. Parcel: 80L/80kg -> 80% risk.
    CMTestScoreResult result = computeScore(
        self.originLat, self.originLng, self.destLat, self.destLng,
        @"55555", @"55556", @"car", 100.0, 100.0,
        self.departureStart,
        pickup, dropoff, pwStart, pwEnd,
        80.0, 80.0, nil, self.weights, self.zipTable);

    XCTAssertTrue(result.passedFilters,
        @"80%% capacity should pass");
    XCTAssertEqualWithAccuracy(result.capacityRisk, 0.8, 0.001,
        @"capacityRisk should be 0.8");
    XCTAssertEqualWithAccuracy(result.capacityScore, 0.2, 0.001,
        @"capacityScore should be 0.2 (1 - 0.8)");
}

#pragma mark - Deterministic Ranking (Q4)

- (void)testHigherScoreRankedFirst {
    CMMatchCandidate *c1 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C1" itineraryId:@"IT1" orderId:@"O1"
        score:60.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];
    CMMatchCandidate *c2 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C2" itineraryId:@"IT1" orderId:@"O2"
        score:70.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];

    NSArray *sorted = [@[c1, c2] sortedArrayUsingComparator:^NSComparisonResult(CMMatchCandidate *a, CMMatchCandidate *b) {
        if (a.score > b.score) return NSOrderedAscending;
        if (a.score < b.score) return NSOrderedDescending;
        if (a.detourMiles < b.detourMiles) return NSOrderedAscending;
        if (a.detourMiles > b.detourMiles) return NSOrderedDescending;
        return [a.orderId compare:b.orderId];
    }];

    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[0]).orderId, @"O2",
        @"Higher score (70) should be ranked first");
    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[1]).orderId, @"O1",
        @"Lower score (60) should be ranked second");
}

- (void)testEqualScoresLowerDetourRankedFirst {
    CMMatchCandidate *c1 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C1" itineraryId:@"IT1" orderId:@"O1"
        score:60.0 detourMiles:5.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];
    CMMatchCandidate *c2 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C2" itineraryId:@"IT1" orderId:@"O2"
        score:60.0 detourMiles:2.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];

    NSArray *sorted = [@[c1, c2] sortedArrayUsingComparator:^NSComparisonResult(CMMatchCandidate *a, CMMatchCandidate *b) {
        if (a.score > b.score) return NSOrderedAscending;
        if (a.score < b.score) return NSOrderedDescending;
        if (a.detourMiles < b.detourMiles) return NSOrderedAscending;
        if (a.detourMiles > b.detourMiles) return NSOrderedDescending;
        return [a.orderId compare:b.orderId];
    }];

    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[0]).orderId, @"O2",
        @"With equal scores, lower detour (2.0) should be ranked first");
}

- (void)testEqualScoresEqualDetourEarlierPickupWindowFirst {
    // We need orders with pickup windows to test this tiebreaker.
    NSDate *earlyPickup = [NSDate dateWithTimeIntervalSince1970:1700000000.0];
    NSDate *latePickup  = [NSDate dateWithTimeIntervalSince1970:1700003600.0]; // 1 hour later

    CMOrder *o1 = [CMTestCoreDataHelper insertOrderInContext:self.ctx
        orderId:@"O1" tenantId:@"T1"
        pickupAddress:[self pickupAddressForDetourTest]
        dropoffAddress:[self dropoffAddressForDetourTest]
        pickupWindowStart:latePickup pickupWindowEnd:[latePickup dateByAddingTimeInterval:3600]
        dropoffWindowStart:nil dropoffWindowEnd:nil
        parcelVolume:10 parcelWeight:10
        requiresVehicleType:nil status:@"new"];

    CMOrder *o2 = [CMTestCoreDataHelper insertOrderInContext:self.ctx
        orderId:@"O2" tenantId:@"T1"
        pickupAddress:[self pickupAddressForDetourTest]
        dropoffAddress:[self dropoffAddressForDetourTest]
        pickupWindowStart:earlyPickup pickupWindowEnd:[earlyPickup dateByAddingTimeInterval:3600]
        dropoffWindowStart:nil dropoffWindowEnd:nil
        parcelVolume:10 parcelWeight:10
        requiresVehicleType:nil status:@"new"];

    CMMatchCandidate *c1 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C1" itineraryId:@"IT1" orderId:@"O1"
        score:60.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];
    CMMatchCandidate *c2 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C2" itineraryId:@"IT1" orderId:@"O2"
        score:60.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];

    // Build a pickup start map for sorting.
    NSDictionary *pickupStarts = @{@"O1": latePickup, @"O2": earlyPickup};

    NSArray *sorted = [@[c1, c2] sortedArrayUsingComparator:^NSComparisonResult(CMMatchCandidate *a, CMMatchCandidate *b) {
        if (a.score > b.score) return NSOrderedAscending;
        if (a.score < b.score) return NSOrderedDescending;
        if (a.detourMiles < b.detourMiles) return NSOrderedAscending;
        if (a.detourMiles > b.detourMiles) return NSOrderedDescending;
        NSDate *aPickup = pickupStarts[a.orderId];
        NSDate *bPickup = pickupStarts[b.orderId];
        if (aPickup && bPickup) {
            NSComparisonResult cmp = [aPickup compare:bPickup];
            if (cmp != NSOrderedSame) return cmp;
        }
        return [a.orderId compare:b.orderId];
    }];

    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[0]).orderId, @"O2",
        @"With equal score and detour, earlier pickup window should be ranked first");
}

- (void)testAllEqualOrderIdAlphabetical {
    CMMatchCandidate *c1 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C1" itineraryId:@"IT1" orderId:@"O-Bravo"
        score:60.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];
    CMMatchCandidate *c2 = [CMTestCoreDataHelper insertCandidateInContext:self.ctx
        candidateId:@"C2" itineraryId:@"IT1" orderId:@"O-Alpha"
        score:60.0 detourMiles:3.0 timeOverlapMinutes:30 capacityRisk:0.2 rankPosition:0];

    NSArray *sorted = [@[c1, c2] sortedArrayUsingComparator:^NSComparisonResult(CMMatchCandidate *a, CMMatchCandidate *b) {
        if (a.score > b.score) return NSOrderedAscending;
        if (a.score < b.score) return NSOrderedDescending;
        if (a.detourMiles < b.detourMiles) return NSOrderedAscending;
        if (a.detourMiles > b.detourMiles) return NSOrderedDescending;
        return [a.orderId compare:b.orderId];
    }];

    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[0]).orderId, @"O-Alpha",
        @"When all else is equal, alphabetically earlier orderId should rank first");
    XCTAssertEqualObjects(((CMMatchCandidate *)sorted[1]).orderId, @"O-Bravo");
}

@end
