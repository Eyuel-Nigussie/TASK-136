//
//  CMAutoScorer_OnTime.h
//  CourierMatch
//
//  Automatic scorer: "on_time_within_10min".
//  Awards full points if the order was delivered within 10 minutes of
//  the dropoffWindowEnd, otherwise 0 points.
//  See design.md §9.2.
//

#import <Foundation/Foundation.h>
#import "CMAutoScorerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAutoScorer_OnTime : NSObject <CMAutoScorerProtocol>
@end

NS_ASSUME_NONNULL_END
