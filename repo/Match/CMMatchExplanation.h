//
//  CMMatchExplanation.h
//  CourierMatch
//
//  Builds explanation component arrays and renders summary strings.
//  Each component is { label: NSString, delta: NSNumber }.
//  Stable factor order: time, detour, capacity, vehicle, penalties.
//  See design.md section 5.3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMMatchExplanation : NSObject

/// Builds an ordered array of explanation component dictionaries.
/// Each dictionary has keys: "label" (NSString), "delta" (NSNumber, double).
/// Order: time, detour, capacity, vehicle.
/// @param timeDelta   The time-fit score contribution (wTime * timeFitScore).
/// @param detourDelta The detour score contribution (wDetour * detourScore).
/// @param capacityDelta The capacity score contribution (wCapacity * capacityScore).
/// @param vehicleDelta The vehicle match contribution (wVehicle * vehicleScore).
/// @return Ordered NSArray of NSDictionary components.
+ (NSArray<NSDictionary<NSString *, id> *> *)componentsWithTimeDelta:(double)timeDelta
                                                         detourDelta:(double)detourDelta
                                                       capacityDelta:(double)capacityDelta
                                                        vehicleDelta:(double)vehicleDelta;

/// Renders a human-readable summary string from an array of explanation components.
/// Example: "+30.0 time fit, +20.0 detour, +15.0 capacity, +10.0 vehicle"
/// @param components The ordered array produced by `componentsWithTimeDelta:...`.
/// @return A formatted string.
+ (NSString *)summaryStringFromComponents:(NSArray<NSDictionary<NSString *, id> *> *)components;

/// Builds a time-fit explanation string for the courier UI.
/// Example: "arrives ~9:42 AM, window 9:30 AM-10:30 AM (estimated - offline routing)"
/// @param etaAtPickup   The estimated time of arrival at the pickup location.
/// @param windowStart   The order's pickup window start.
/// @param windowEnd     The order's pickup window end.
/// @return A formatted explanation string.
+ (NSString *)timeFitExplanationWithETA:(NSDate *)etaAtPickup
                            windowStart:(NSDate *)windowStart
                              windowEnd:(NSDate *)windowEnd;

/// Builds a detour explanation string with the offline routing disclaimer.
/// Example: "4.2 mi detour (estimated - offline routing)"
/// @param detourMiles The adjusted detour distance in miles.
/// @return A formatted explanation string.
+ (NSString *)detourExplanationWithMiles:(double)detourMiles;

@end

NS_ASSUME_NONNULL_END
