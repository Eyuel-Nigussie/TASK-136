//
//  CMMatchEngine.m
//  CourierMatch
//

#import "CMMatchEngine.h"
#import "CMMatchCandidate.h"
#import "CMItinerary.h"
#import "CMOrder.h"
#import "CMAddress.h"
#import "CMGeoMath.h"
#import "CMZipMetroTable.h"
#import "CMVehicleSpeedTable.h"
#import "CMMatchScoringWeights.h"
#import "CMMatchExplanation.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMTenantRepository.h"
#import "CMOrderRepository.h"
#import "CMMatchCandidateRepository.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSString * const kLogTag = @"MatchEngine";

NSNotificationName const CMMatchEngineDidRecomputeNotification = @"CMMatchEngineDidRecomputeNotification";
NSNotificationName const CMMatchEngineTruncatedNotification    = @"CMMatchEngineTruncatedNotification";

// ──────────────────────────────────────────────────────────────────────────────
// Internal struct to hold per-order scoring results before persistence.
// ──────────────────────────────────────────────────────────────────────────────
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
} CMScoreResult;

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - CMMatchEngine
// ──────────────────────────────────────────────────────────────────────────────

@interface CMMatchEngine ()
@property (nonatomic, strong, readwrite, nullable) NSDate *lastRefreshedAt;
@property (nonatomic, strong) dispatch_queue_t engineQueue;
@end

@implementation CMMatchEngine

+ (instancetype)shared {
    static CMMatchEngine *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[CMMatchEngine alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _engineQueue = dispatch_queue_create("com.eaglepoint.couriermatch.matchengine",
                                             DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Thermal / Battery Yield (Q5)
// ──────────────────────────────────────────────────────────────────────────────

/// Returns YES if the device is under thermal or battery stress and we should
/// skip heavy computation. Per Q5: yield when thermalState >= .serious or
/// isLowPowerModeEnabled.
- (BOOL)shouldYieldForSystemConstraints {
    NSProcessInfo *pi = [NSProcessInfo processInfo];
    if (pi.thermalState >= NSProcessInfoThermalStateSerious) {
        CMLogWarn(kLogTag, @"Yielding: thermal state >= serious (%ld)", (long)pi.thermalState);
        return YES;
    }
    if (pi.isLowPowerModeEnabled) {
        CMLogWarn(kLogTag, @"Yielding: low power mode enabled");
        return YES;
    }
    return NO;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Staleness (Q5)
// ──────────────────────────────────────────────────────────────────────────────

- (BOOL)isCandidateStale:(CMMatchCandidate *)candidate {
    if (!candidate) return YES;
    if (candidate.stale) return YES;
    if (!candidate.computedAt) return YES;

    // Load tenant config to get staleness threshold
    CMMatchScoringWeights *weights = [self loadWeightsForTenantId:candidate.tenantId
                                                        inContext:candidate.managedObjectContext];
    NSTimeInterval age = -[candidate.computedAt timeIntervalSinceNow];
    return age > weights.stalenessThreshold;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Last Refreshed Display (Q5)
// ──────────────────────────────────────────────────────────────────────────────

- (NSString *)lastRefreshedDisplayString {
    if (!self.lastRefreshedAt) {
        return @"Not yet refreshed";
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateStyle = NSDateFormatterShortStyle;
    fmt.timeStyle = NSDateFormatterMediumStyle;
    return [NSString stringWithFormat:@"Last refreshed at %@", [fmt stringFromDate:self.lastRefreshedAt]];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Weight Loading
// ──────────────────────────────────────────────────────────────────────────────

/// Loads scoring weights, applying tenant config overrides if available.
- (CMMatchScoringWeights *)loadWeightsForTenantId:(NSString *)tenantId
                                        inContext:(NSManagedObjectContext *)ctx {
    if (!tenantId || !ctx) {
        return [[CMMatchScoringWeights alloc] init];
    }

    CMTenantRepository *tenantRepo = [[CMTenantRepository alloc] initWithContext:ctx];
    NSError *err = nil;
    CMTenant *tenant = [tenantRepo findByTenantId:tenantId error:&err];
    if (tenant && tenant.configJSON) {
        return [[CMMatchScoringWeights alloc] initWithTenantConfig:tenant.configJSON];
    }
    return [[CMMatchScoringWeights alloc] init];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Recompute Candidates
// ──────────────────────────────────────────────────────────────────────────────

- (void)recomputeCandidatesForItinerary:(CMItinerary *)itinerary
                             completion:(void (^)(NSError * _Nullable error))completion {
    if (!itinerary) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([CMError errorWithCode:CMErrorCodeValidationFailed
                                          message:@"Itinerary is nil"]);
            });
        }
        return;
    }

    // Q5: Yield under thermal/battery stress
    if ([self shouldYieldForSystemConstraints]) {
        CMLogInfo(kLogTag, @"Skipping recompute for itinerary %@ due to system constraints",
                  itinerary.itineraryId);
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
        return;
    }

    // Capture itinerary values on the calling thread's context before dispatching
    // to a background context. We need these for computation.
    NSString *itineraryId = [itinerary.itineraryId copy];
    NSString *tenantId = [itinerary.tenantId copy];
    NSString *courierId = [itinerary.courierId copy];
    NSString *vehicleType = [itinerary.vehicleType copy];
    double vehicleCapVolumeL = itinerary.vehicleCapacityVolumeL;
    double vehicleCapWeightKg = itinerary.vehicleCapacityWeightKg;
    NSDate *departureStart = [itinerary.departureWindowStart copy];
    NSDate *departureEnd = [itinerary.departureWindowEnd copy];

    // Origin / destination addresses
    double originLat = itinerary.originAddress.lat;
    double originLng = itinerary.originAddress.lng;
    double destLat   = itinerary.destinationAddress.lat;
    double destLng   = itinerary.destinationAddress.lng;
    NSString *originZip = [itinerary.originAddress.zip copy];
    NSString *destZip   = [itinerary.destinationAddress.zip copy];

    CMLogInfo(kLogTag, @"Starting recompute for itinerary %@", itineraryId);

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSError *error = nil;
        BOOL truncated = NO;
        NSUInteger totalBeforeCap = 0;

        // Load scoring weights from tenant config
        CMMatchScoringWeights *weights = [self loadWeightsForTenantId:tenantId inContext:ctx];

        // Apply tenant urban/rural multiplier overrides to the ZIP table
        CMZipMetroTable *zipTable = [CMZipMetroTable shared];
        zipTable.urbanMultiplier = weights.urbanMultiplier;
        zipTable.ruralMultiplier = weights.ruralMultiplier;

        // ── Step 1: Delete existing candidates for this itinerary ──
        CMMatchCandidateRepository *candidateRepo =
            [[CMMatchCandidateRepository alloc] initWithContext:ctx];
        [candidateRepo deleteAllForItinerary:itineraryId error:&error];
        if (error) {
            CMLogError(kLogTag, @"Failed to delete old candidates: %@", error);
            [self completeOnMain:completion error:error];
            return;
        }

        // ── Step 2: Temporal pre-filter (Q17) ──
        // Fetch orders whose pickup window overlaps ±24h of departure
        NSDate *windowStart = departureStart ?: [NSDate date];
        NSDate *windowEnd   = departureEnd ?: windowStart;
        NSDate *filterStart = [windowStart dateByAddingTimeInterval:-24.0 * 3600.0];
        NSDate *filterEnd   = [windowEnd dateByAddingTimeInterval:24.0 * 3600.0];

        CMOrderRepository *orderRepo = [[CMOrderRepository alloc] initWithContext:ctx];
        NSArray<CMOrder *> *candidateOrders =
            [orderRepo candidateOrdersForWindowStart:filterStart
                                           windowEnd:filterEnd
                                               limit:0
                                               error:&error];
        if (error) {
            CMLogError(kLogTag, @"Failed to fetch candidate orders: %@", error);
            [self completeOnMain:completion error:error];
            return;
        }

        CMLogInfo(kLogTag, @"Temporal pre-filter returned %lu orders for itinerary %@",
                  (unsigned long)candidateOrders.count, itineraryId);

        // ── Step 3: Spatial bounding box pre-filter (Q17) ──
        // 2 x maxDetourMiles x urbanMultiplier around itinerary origin/destination
        double spatialRadius = 2.0 * weights.maxDetourMiles * weights.urbanMultiplier;

        NSMutableArray<CMOrder *> *spatialFiltered = [NSMutableArray array];
        for (CMOrder *order in candidateOrders) {
            CMAddress *pickup  = order.pickupAddress;
            CMAddress *dropoff = order.dropoffAddress;

            if (!pickup || !dropoff) continue;

            // Check if pickup or dropoff is within bounding box of origin
            BOOL nearOrigin = CMGeoEitherPointInBoundingBox(
                pickup.lat, pickup.lng, dropoff.lat, dropoff.lng,
                originLat, originLng, spatialRadius);

            // Check if pickup or dropoff is within bounding box of destination
            BOOL nearDest = CMGeoEitherPointInBoundingBox(
                pickup.lat, pickup.lng, dropoff.lat, dropoff.lng,
                destLat, destLng, spatialRadius);

            if (nearOrigin || nearDest) {
                [spatialFiltered addObject:order];
            }
        }

        CMLogInfo(kLogTag, @"Spatial pre-filter: %lu -> %lu orders",
                  (unsigned long)candidateOrders.count,
                  (unsigned long)spatialFiltered.count);

        // ── Step 4: Score each order, apply hard filters ──
        NSMutableArray<NSDictionary *> *scoredResults = [NSMutableArray array];

        for (CMOrder *order in spatialFiltered) {
            // Hard filter: terminal state (delivered, cancelled)
            if ([order isTerminal]) {
                continue;
            }

            // Hard filter: assigned to another courier and not in "new" state
            if (order.assignedCourierId.length > 0 &&
                ![order.assignedCourierId isEqualToString:courierId] &&
                ![order.status isEqualToString:CMOrderStatusNew]) {
                continue;
            }

            // Hard filter: vehicle mismatch
            if (order.requiresVehicleType.length > 0 && vehicleType.length > 0 &&
                ![order.requiresVehicleType isEqualToString:vehicleType]) {
                continue;
            }

            CMScoreResult result = [self scoreOrder:order
                                     withOriginLat:originLat originLng:originLng
                                           destLat:destLat destLng:destLng
                                         originZip:originZip destZip:destZip
                                       vehicleType:vehicleType
                                vehicleCapVolumeL:vehicleCapVolumeL
                               vehicleCapWeightKg:vehicleCapWeightKg
                                    departureStart:departureStart
                                           weights:weights
                                          zipTable:zipTable];

            if (!result.passedFilters) {
                continue;
            }

            NSDictionary *entry = @{
                @"order": order,
                @"result": [NSValue valueWithBytes:&result objCType:@encode(CMScoreResult)],
            };
            [scoredResults addObject:entry];
        }

        CMLogInfo(kLogTag, @"After hard filters: %lu candidates for itinerary %@",
                  (unsigned long)scoredResults.count, itineraryId);

        // ── Step 5: Sort per Q4 (score DESC, detourMiles ASC, pickupWindowStart ASC, orderId ASC) ──
        [scoredResults sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            CMScoreResult ra, rb;
            [a[@"result"] getValue:&ra];
            [b[@"result"] getValue:&rb];
            CMOrder *oa = a[@"order"];
            CMOrder *ob = b[@"order"];

            // score DESC
            if (ra.score > rb.score) return NSOrderedAscending;
            if (ra.score < rb.score) return NSOrderedDescending;

            // detourMiles ASC
            if (ra.detourMiles < rb.detourMiles) return NSOrderedAscending;
            if (ra.detourMiles > rb.detourMiles) return NSOrderedDescending;

            // pickupWindowStart ASC
            NSComparisonResult pickupCmp = [oa.pickupWindowStart compare:ob.pickupWindowStart];
            if (pickupCmp != NSOrderedSame) return pickupCmp;

            // orderId ASC
            return [oa.orderId compare:ob.orderId];
        }];

        // ── Step 6: Cap at 500 candidates (Q17) ──
        totalBeforeCap = scoredResults.count;
        if (scoredResults.count > weights.maxCandidatesPerItinerary) {
            truncated = YES;
            CMLogWarn(kLogTag, @"Truncating candidates from %lu to %lu for itinerary %@",
                      (unsigned long)scoredResults.count,
                      (unsigned long)weights.maxCandidatesPerItinerary,
                      itineraryId);
            [scoredResults removeObjectsInRange:
                NSMakeRange(weights.maxCandidatesPerItinerary,
                            scoredResults.count - weights.maxCandidatesPerItinerary)];
        }

        // ── Step 7: Persist candidates with rank positions ──
        NSDate *now = [NSDate date];
        int32_t rank = 1;

        for (NSDictionary *entry in scoredResults) {
            CMOrder *order = entry[@"order"];
            CMScoreResult result;
            [entry[@"result"] getValue:&result];

            CMMatchCandidate *candidate = [candidateRepo insertCandidate];
            candidate.tenantId          = tenantId;
            candidate.itineraryId       = itineraryId;
            candidate.orderId           = order.orderId;
            candidate.score             = result.score;
            candidate.detourMiles       = result.detourMiles;
            candidate.timeOverlapMinutes = result.timeOverlapMinutes;
            candidate.capacityRisk      = result.capacityRisk;
            candidate.rankPosition      = rank;
            candidate.computedAt        = now;
            candidate.stale             = NO;

            // Build explanation components (design.md section 5.3)
            candidate.explanationComponents =
                [CMMatchExplanation componentsWithTimeDelta:result.timeDelta
                                               detourDelta:result.detourDelta
                                             capacityDelta:result.capacityDelta
                                              vehicleDelta:result.vehicleDelta];

            rank++;
        }

        // Save the context
        NSError *saveError = nil;
        if (![ctx cm_saveWithError:&saveError]) {
            CMLogError(kLogTag, @"Failed to save candidates: %@", saveError);
            [self completeOnMain:completion error:saveError];
            return;
        }

        CMLogInfo(kLogTag, @"Saved %lu candidates for itinerary %@",
                  (unsigned long)scoredResults.count, itineraryId);

        // Update the last refreshed timestamp
        dispatch_async(dispatch_get_main_queue(), ^{
            self.lastRefreshedAt = now;
        });

        // Post notifications
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CMMatchEngineDidRecomputeNotification
                              object:self
                            userInfo:@{ @"itineraryId": itineraryId }];
        });

        // Build result error (may be a non-fatal truncation warning)
        NSError *resultError = nil;
        if (truncated) {
            resultError = [CMError errorWithCode:CMErrorCodeMatchCandidateTruncated
                                         message:[NSString stringWithFormat:
                @"Candidate list truncated to %lu (was %lu). "
                 "Consider refining itinerary criteria.",
                (unsigned long)weights.maxCandidatesPerItinerary,
                (unsigned long)totalBeforeCap]];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:CMMatchEngineTruncatedNotification
                                  object:self
                                userInfo:@{
                    @"itineraryId": itineraryId,
                    @"totalBeforeCap": @(totalBeforeCap),
                }];
            });
        }

        [self completeOnMain:completion error:resultError];
    }];
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Scoring Core
// ──────────────────────────────────────────────────────────────────────────────

/// Scores a single order against the itinerary.
/// Returns a CMScoreResult with passedFilters = NO if a hard filter eliminates it.
- (CMScoreResult)scoreOrder:(CMOrder *)order
             withOriginLat:(double)originLat originLng:(double)originLng
                   destLat:(double)destLat destLng:(double)destLng
                 originZip:(NSString *)originZip destZip:(NSString *)destZip
               vehicleType:(NSString *)vehicleType
          vehicleCapVolumeL:(double)vehicleCapVolumeL
         vehicleCapWeightKg:(double)vehicleCapWeightKg
             departureStart:(NSDate *)departureStart
                    weights:(CMMatchScoringWeights *)weights
                   zipTable:(CMZipMetroTable *)zipTable {
    CMScoreResult result;
    memset(&result, 0, sizeof(result));
    result.passedFilters = NO;

    CMAddress *pickup  = order.pickupAddress;
    CMAddress *dropoff = order.dropoffAddress;
    if (!pickup || !dropoff) {
        return result;
    }

    // ── Q2: Detour calculation ──
    // greatCircle(origin -> pickup -> dropoff -> destination) - greatCircle(origin -> destination)
    double directDistance = CMGeoDistanceMiles(originLat, originLng, destLat, destLng);
    double detourRoute = CMGeoMultiLegDistanceMiles(
        originLat, originLng,
        pickup.lat, pickup.lng,
        dropoff.lat, dropoff.lng,
        destLat, destLng);
    double rawDetourMiles = detourRoute - directDistance;
    if (rawDetourMiles < 0.0) rawDetourMiles = 0.0;

    // Apply urban multiplier (Q2)
    BOOL bothMetro = [zipTable areBothMetroZip1:originZip zip2:pickup.zip];
    double multiplier = [zipTable multiplierForBothMetro:bothMetro];
    double adjustedDetourMiles = rawDetourMiles * multiplier;

    // Hard filter: detour > maxDetourMiles
    if (adjustedDetourMiles > weights.maxDetourMiles) {
        return result;
    }

    result.detourMiles = adjustedDetourMiles;

    // ── Q3: Time fit with ETA ──
    BOOL isUrban = bothMetro;
    double travelMinutesToPickup = [CMVehicleSpeedTable travelMinutesForMiles:
        CMGeoDistanceMiles(originLat, originLng, pickup.lat, pickup.lng) * multiplier
                                                                 vehicleType:vehicleType
                                                                     isUrban:isUrban];

    // etaAtPickup = departureStart + travelMinutes
    NSDate *etaAtPickup = departureStart
        ? [departureStart dateByAddingTimeInterval:travelMinutesToPickup * 60.0]
        : nil;

    // overlap = min(orderPickup.end, etaAtPickup + maxWait) - max(orderPickup.start, etaAtPickup)
    double overlapMinutes = 0.0;
    if (etaAtPickup && order.pickupWindowStart && order.pickupWindowEnd) {
        NSDate *etaPlusWait = [etaAtPickup dateByAddingTimeInterval:weights.maxWaitMinutes * 60.0];
        NSDate *overlapEnd   = ([order.pickupWindowEnd compare:etaPlusWait] == NSOrderedAscending)
                               ? order.pickupWindowEnd : etaPlusWait;
        NSDate *overlapStart = ([order.pickupWindowStart compare:etaAtPickup] == NSOrderedDescending)
                               ? order.pickupWindowStart : etaAtPickup;
        NSTimeInterval overlapSeconds = [overlapEnd timeIntervalSinceDate:overlapStart];
        overlapMinutes = overlapSeconds / 60.0;
    }

    // Hard filter: time overlap < minTimeOverlapMinutes
    if (overlapMinutes < weights.minTimeOverlapMinutes) {
        return result;
    }

    result.timeOverlapMinutes = overlapMinutes;

    // ── Capacity check ──
    // capacityRisk: 0.0 = no risk, 1.0 = at or over capacity
    double volumeRisk = 0.0;
    double weightRisk = 0.0;

    if (vehicleCapVolumeL > 0.0) {
        volumeRisk = order.parcelVolumeL / vehicleCapVolumeL;
    }
    if (vehicleCapWeightKg > 0.0) {
        weightRisk = order.parcelWeightKg / vehicleCapWeightKg;
    }

    double capacityRisk = fmax(volumeRisk, weightRisk);

    // Hard filter: capacity exceeded (volume or weight)
    if (volumeRisk > 1.0 || weightRisk > 1.0) {
        return result;
    }

    result.capacityRisk = capacityRisk;

    // ── Component scores ──

    // timeFitScore = min(overlap / 60, 1.0)
    double timeFitScore = fmin(overlapMinutes / 60.0, 1.0);
    result.timeFitScore = timeFitScore;

    // detourScore = 1 - (adjustedDetourMiles / maxDetourMiles)
    double detourScore = 1.0 - (adjustedDetourMiles / weights.maxDetourMiles);
    if (detourScore < 0.0) detourScore = 0.0;
    result.detourScore = detourScore;

    // capacityScore = 1 - capacityRisk (higher is better: less capacity used = better)
    double capacityScore = 1.0 - capacityRisk;
    if (capacityScore < 0.0) capacityScore = 0.0;
    result.capacityScore = capacityScore;

    // vehicleScore = 1.0 if no requirement or match, 0.0 if mismatch (already filtered)
    double vehicleScore = 1.0;
    if (order.requiresVehicleType.length > 0) {
        vehicleScore = [order.requiresVehicleType isEqualToString:vehicleType] ? 1.0 : 0.0;
    }
    result.vehicleScore = vehicleScore;

    // ── Weighted total (design.md section 5.2) ──
    result.timeDelta     = weights.wTime     * timeFitScore;
    result.detourDelta   = weights.wDetour   * detourScore;
    result.capacityDelta = weights.wCapacity * capacityScore;
    result.vehicleDelta  = weights.wVehicle  * vehicleScore;

    result.score = result.timeDelta + result.detourDelta + result.capacityDelta + result.vehicleDelta;
    result.passedFilters = YES;

    return result;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Rank Candidates (Read Path)
// ──────────────────────────────────────────────────────────────────────────────

- (NSArray<CMMatchCandidate *> *)rankCandidatesForItinerary:(NSString *)itineraryId
                                                       error:(NSError **)error {
    if (!itineraryId) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Itinerary ID is nil"];
        }
        return nil;
    }

    NSManagedObjectContext *ctx = [CMCoreDataStack shared].viewContext;
    CMMatchCandidateRepository *repo = [[CMMatchCandidateRepository alloc] initWithContext:ctx];

    // Repository already sorts by score DESC, detourMiles ASC, orderId ASC (Q4)
    NSArray<CMMatchCandidate *> *candidates = [repo candidatesForItinerary:itineraryId
                                                                 staleOnly:NO
                                                                     error:error];
    if (!candidates) {
        return nil;
    }

    // The repository sort covers score DESC, detourMiles ASC, orderId ASC.
    // Q4 also requires orderPickupWindowStart ASC as third tiebreaker.
    // Since Core Data doesn't have easy access to the related order's pickupWindowStart
    // in the sort descriptors, we do a stable re-sort here for full compliance.
    // We need to load orders to get pickupWindowStart for tie-breaking.
    CMOrderRepository *orderRepo = [[CMOrderRepository alloc] initWithContext:ctx];
    NSMutableDictionary<NSString *, NSDate *> *pickupStartByOrderId = [NSMutableDictionary dictionary];
    for (CMMatchCandidate *c in candidates) {
        CMOrder *order = [orderRepo findByOrderId:c.orderId error:nil];
        if (order && order.pickupWindowStart) {
            pickupStartByOrderId[c.orderId] = order.pickupWindowStart;
        }
    }

    NSArray<CMMatchCandidate *> *sorted = [candidates sortedArrayUsingComparator:
        ^NSComparisonResult(CMMatchCandidate *a, CMMatchCandidate *b) {
        // score DESC
        if (a.score > b.score) return NSOrderedAscending;
        if (a.score < b.score) return NSOrderedDescending;

        // detourMiles ASC
        if (a.detourMiles < b.detourMiles) return NSOrderedAscending;
        if (a.detourMiles > b.detourMiles) return NSOrderedDescending;

        // pickupWindowStart ASC
        NSDate *aPickup = pickupStartByOrderId[a.orderId];
        NSDate *bPickup = pickupStartByOrderId[b.orderId];
        if (aPickup && bPickup) {
            NSComparisonResult cmp = [aPickup compare:bPickup];
            if (cmp != NSOrderedSame) return cmp;
        } else if (aPickup) {
            return NSOrderedAscending;
        } else if (bPickup) {
            return NSOrderedDescending;
        }

        // orderId ASC
        return [a.orderId compare:b.orderId];
    }];

    // Assign 1-based rank positions (Q4: persist rankPosition)
    int32_t rank = 1;
    for (CMMatchCandidate *c in sorted) {
        if (c.rankPosition != rank) {
            c.rankPosition = rank;
        }
        rank++;
    }

    // Save rank position updates if any changed
    NSError *saveError = nil;
    if (ctx.hasChanges && ![ctx cm_saveWithError:&saveError]) {
        CMLogWarn(kLogTag, @"Failed to save rank position updates: %@", saveError);
        // Non-fatal: we still return the sorted array
    }

    return sorted;
}

// ──────────────────────────────────────────────────────────────────────────────
#pragma mark - Helpers
// ──────────────────────────────────────────────────────────────────────────────

- (void)completeOnMain:(void (^)(NSError * _Nullable))completion error:(NSError * _Nullable)error {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
    });
}

@end
