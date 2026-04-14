//
//  CMMatchExplanation.m
//  CourierMatch
//

#import "CMMatchExplanation.h"

@implementation CMMatchExplanation

+ (NSArray<NSDictionary<NSString *, id> *> *)componentsWithTimeDelta:(double)timeDelta
                                                         detourDelta:(double)detourDelta
                                                       capacityDelta:(double)capacityDelta
                                                        vehicleDelta:(double)vehicleDelta {
    // Stable factor order: time, detour, capacity, vehicle (per design.md section 5.3)
    return @[
        @{ @"label": @"time fit",  @"delta": @(timeDelta) },
        @{ @"label": @"detour",    @"delta": @(detourDelta) },
        @{ @"label": @"capacity",  @"delta": @(capacityDelta) },
        @{ @"label": @"vehicle",   @"delta": @(vehicleDelta) },
    ];
}

+ (NSString *)summaryStringFromComponents:(NSArray<NSDictionary<NSString *, id> *> *)components {
    if (!components || components.count == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:components.count];
    for (NSDictionary<NSString *, id> *comp in components) {
        NSString *label = comp[@"label"];
        double delta = [comp[@"delta"] doubleValue];
        NSString *sign = (delta >= 0.0) ? @"+" : @"";
        NSString *formatted = [NSString stringWithFormat:@"%@%.1f %@", sign, delta, label];
        [parts addObject:formatted];
    }

    return [parts componentsJoinedByString:@", "];
}

+ (NSString *)timeFitExplanationWithETA:(NSDate *)etaAtPickup
                            windowStart:(NSDate *)windowStart
                              windowEnd:(NSDate *)windowEnd {
    if (!etaAtPickup || !windowStart || !windowEnd) {
        return @"time fit data unavailable";
    }

    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.dateStyle = NSDateFormatterNoStyle;
    timeFormatter.timeStyle = NSDateFormatterShortStyle;
    timeFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

    NSString *etaStr = [timeFormatter stringFromDate:etaAtPickup];
    NSString *startStr = [timeFormatter stringFromDate:windowStart];
    NSString *endStr = [timeFormatter stringFromDate:windowEnd];

    return [NSString stringWithFormat:@"arrives ~%@, window %@\u2013%@ (estimated \u2014 offline routing)",
            etaStr, startStr, endStr];
}

+ (NSString *)detourExplanationWithMiles:(double)detourMiles {
    return [NSString stringWithFormat:@"%.1f mi detour (estimated \u2014 offline routing)",
            detourMiles];
}

@end
