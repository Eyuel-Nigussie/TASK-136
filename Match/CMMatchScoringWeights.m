//
//  CMMatchScoringWeights.m
//  CourierMatch
//

#import "CMMatchScoringWeights.h"

@implementation CMMatchScoringWeights

- (instancetype)init {
    return [self initWithTenantConfig:nil];
}

- (instancetype)initWithTenantConfig:(NSDictionary *)configJSON {
    if ((self = [super init])) {
        // Set defaults per design.md section 5.2
        _wTime     = 30.0;
        _wDetour   = 20.0;
        _wCapacity = 15.0;
        _wVehicle  = 10.0;

        _maxDetourMiles        = 8.0;
        _minTimeOverlapMinutes = 20.0;
        _maxWaitMinutes        = 60.0;

        _urbanMultiplier = 1.35;
        _ruralMultiplier = 1.15;

        _maxCandidatesPerItinerary = 500;
        _stalenessThreshold = 300.0; // 5 minutes

        // Apply tenant overrides from configJSON
        if (configJSON) {
            [self applyOverrides:configJSON];
        }
    }
    return self;
}

- (void)applyOverrides:(NSDictionary *)config {
    id val;

    val = config[@"w_time"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        _wTime = [val doubleValue];
    }
    val = config[@"w_detour"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        _wDetour = [val doubleValue];
    }
    val = config[@"w_capacity"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        _wCapacity = [val doubleValue];
    }
    val = config[@"w_vehicle"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        _wVehicle = [val doubleValue];
    }
    val = config[@"maxDetourMiles"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d > 0) _maxDetourMiles = d;
    }
    val = config[@"minTimeOverlapMinutes"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d >= 0) _minTimeOverlapMinutes = d;
    }
    val = config[@"maxWaitMinutes"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d > 0) _maxWaitMinutes = d;
    }
    val = config[@"urbanMultiplier"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d > 0) _urbanMultiplier = d;
    }
    val = config[@"ruralMultiplier"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d > 0) _ruralMultiplier = d;
    }
    val = config[@"maxCandidatesPerItinerary"];
    if (val && [val respondsToSelector:@selector(unsignedIntegerValue)]) {
        NSUInteger u = [val unsignedIntegerValue];
        if (u > 0) _maxCandidatesPerItinerary = u;
    }
    val = config[@"stalenessThreshold"];
    if (val && [val respondsToSelector:@selector(doubleValue)]) {
        double d = [val doubleValue];
        if (d > 0) _stalenessThreshold = d;
    }
}

- (double)maxPossibleScore {
    return self.wTime + self.wDetour + self.wCapacity + self.wVehicle;
}

@end
