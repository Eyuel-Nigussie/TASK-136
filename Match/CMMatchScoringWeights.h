//
//  CMMatchScoringWeights.h
//  CourierMatch
//
//  Holds current scoring weights and thresholds for the match engine.
//  Loads defaults, then applies per-tenant overrides from configJSON.
//  See design.md section 5.2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMMatchScoringWeights : NSObject

/// Creates a weights instance with the default values.
- (instancetype)init;

/// Creates a weights instance, applying tenant overrides from configJSON.
/// Recognized keys: w_time, w_detour, w_capacity, w_vehicle,
///   maxDetourMiles, minTimeOverlapMinutes, maxWaitMinutes,
///   urbanMultiplier, ruralMultiplier.
- (instancetype)initWithTenantConfig:(nullable NSDictionary *)configJSON NS_DESIGNATED_INITIALIZER;

// --- Scoring weights ---
@property (nonatomic, assign) double wTime;       // default 30
@property (nonatomic, assign) double wDetour;     // default 20
@property (nonatomic, assign) double wCapacity;   // default 15
@property (nonatomic, assign) double wVehicle;    // default 10

// --- Thresholds ---
@property (nonatomic, assign) double maxDetourMiles;        // default 8.0
@property (nonatomic, assign) double minTimeOverlapMinutes; // default 20
@property (nonatomic, assign) double maxWaitMinutes;        // default 60

// --- Multipliers (Q2) ---
@property (nonatomic, assign) double urbanMultiplier;  // default 1.35
@property (nonatomic, assign) double ruralMultiplier;  // default 1.15

// --- Pre-filter limits (Q17) ---
@property (nonatomic, assign) NSUInteger maxCandidatesPerItinerary; // default 500

/// Staleness threshold in seconds. If a candidate was computed more than this many
/// seconds ago, it is considered stale and should be recomputed.
/// Default: 300 (5 minutes).
@property (nonatomic, assign) NSTimeInterval stalenessThreshold;

/// Returns the maximum weight sum (wTime + wDetour + wCapacity + wVehicle).
- (double)maxPossibleScore;

@end

NS_ASSUME_NONNULL_END
