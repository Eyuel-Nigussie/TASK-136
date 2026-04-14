//
//  CMAutoScorer_OnTime.m
//  CourierMatch
//

#import "CMAutoScorer_OnTime.h"
#import "CMOrder.h"
#import "CMError.h"

/// Tolerance in seconds: 10 minutes.
static const NSTimeInterval kOnTimeToleranceSeconds = 10.0 * 60.0;

@implementation CMAutoScorer_OnTime

- (NSDictionary *)evaluateForOrder:(CMOrder *)order
                       attachments:(NSArray<CMAttachment *> *)attachments
                             error:(NSError **)error {
    NSParameterAssert(order);

    // The order must be in delivered status for scoring.
    if (![order.status isEqualToString:CMOrderStatusDelivered]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"on_time_within_10min: order is not in delivered status"];
        }
        return nil;
    }

    NSDate *dropoffWindowEnd = order.dropoffWindowEnd;
    if (!dropoffWindowEnd) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"on_time_within_10min: order has no dropoffWindowEnd"];
        }
        return nil;
    }

    // Use updatedAt as the actual delivery timestamp (set when status changed to delivered).
    NSDate *actualDeliveryTime = order.updatedAt;
    if (!actualDeliveryTime) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"on_time_within_10min: order has no updatedAt timestamp"];
        }
        return nil;
    }

    // The delivery is on time if actualDeliveryTime <= dropoffWindowEnd + 10 minutes.
    NSDate *deadline = [dropoffWindowEnd dateByAddingTimeInterval:kOnTimeToleranceSeconds];
    BOOL onTime = ([actualDeliveryTime compare:deadline] != NSOrderedDescending);

    double points = onTime ? 1.0 : 0.0;
    NSString *evidence;
    if (onTime) {
        evidence = [NSString stringWithFormat:
                    @"Delivered at %@ within tolerance of %@ (+10min)",
                    actualDeliveryTime, dropoffWindowEnd];
    } else {
        NSTimeInterval late = [actualDeliveryTime timeIntervalSinceDate:deadline];
        evidence = [NSString stringWithFormat:
                    @"Delivered at %@ — %.0f seconds past tolerance of %@ (+10min)",
                    actualDeliveryTime, late, dropoffWindowEnd];
    }

    return @{
        CMAutoScorerResultPointsKey:    @(points),
        CMAutoScorerResultMaxPointsKey: @(1.0),
        CMAutoScorerResultEvidenceKey:  evidence
    };
}

@end
