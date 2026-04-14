//
//  CMMatchEngine.h
//  CourierMatch
//
//  The core match engine. For each active itinerary, scores candidate orders
//  using a weighted formula (time fit, detour, capacity, vehicle match),
//  applies hard filters, and persists ranked CMMatchCandidate objects.
//
//  All heavy computation runs on background queues; completions fire on main.
//  Yields when thermal state >= .serious or low-power mode is enabled (Q5).
//
//  See design.md section 5.2, Q2, Q3, Q4, Q5, Q17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMItinerary;
@class CMMatchCandidate;

/// Posted when candidates have been recomputed for an itinerary.
/// userInfo: { @"itineraryId": NSString }
extern NSNotificationName const CMMatchEngineDidRecomputeNotification;

/// Posted when the candidate list was truncated at 500 (Q17).
/// userInfo: { @"itineraryId": NSString, @"totalBeforeCap": NSNumber }
extern NSNotificationName const CMMatchEngineTruncatedNotification;

@interface CMMatchEngine : NSObject

+ (instancetype)shared;

/// Full recompute of match candidates for a given itinerary.
/// Runs scoring, filtering, and persistence on a background queue.
/// Completion is called on the main queue with an optional error.
/// The error may carry CMErrorCodeMatchCandidateTruncated (5005) as a
/// non-fatal warning if the candidate list was capped at 500.
/// @param itinerary The itinerary to compute candidates for.
/// @param completion Called on the main queue when done.
- (void)recomputeCandidatesForItinerary:(CMItinerary *)itinerary
                             completion:(void (^)(NSError * _Nullable error))completion;

/// Returns YES if the candidate's computedAt date is older than the staleness threshold,
/// or if the candidate is explicitly marked stale.
/// Per Q5: this is checked when the courier opens the itinerary list.
/// @param candidate The match candidate to check.
/// @return YES if stale and should be recomputed.
- (BOOL)isCandidateStale:(CMMatchCandidate *)candidate;

/// Returns sorted, ranked candidates for the given itinerary from the persistent store.
/// Candidates are sorted per Q4: score DESC, detourMiles ASC, orderPickupWindowStart ASC, orderId ASC.
/// Each candidate's rankPosition is set (1-based) before returning.
/// @param itineraryId The itinerary ID to look up candidates for.
/// @param error On failure, contains the error.
/// @return An array of CMMatchCandidate objects, or nil on error.
- (nullable NSArray<CMMatchCandidate *> *)rankCandidatesForItinerary:(NSString *)itineraryId
                                                               error:(NSError **)error;

/// The "Last refreshed at..." timestamp for the most recent recomputation.
/// Returns nil if no computation has been done.
@property (nonatomic, strong, readonly, nullable) NSDate *lastRefreshedAt;

/// Human-readable "Last refreshed at ..." string for display.
/// Returns @"Not yet refreshed" if no computation has occurred.
- (NSString *)lastRefreshedDisplayString;

@end

NS_ASSUME_NONNULL_END
