//
//  CMAutoScorer_PhotoAttached.h
//  CourierMatch
//
//  Automatic scorer: "photo_attached".
//  Awards full points if at least one attachment with an image/* MIME type
//  exists for the order. Otherwise 0 points.
//  See design.md §9.2.
//

#import <Foundation/Foundation.h>
#import "CMAutoScorerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAutoScorer_PhotoAttached : NSObject <CMAutoScorerProtocol>
@end

NS_ASSUME_NONNULL_END
