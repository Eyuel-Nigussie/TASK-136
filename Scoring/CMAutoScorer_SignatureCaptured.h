//
//  CMAutoScorer_SignatureCaptured.h
//  CourierMatch
//
//  Automatic scorer: "signature_captured".
//  Awards full points if a signature attachment is present for the order.
//  See design.md §9.2.
//

#import <Foundation/Foundation.h>
#import "CMAutoScorerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAutoScorer_SignatureCaptured : NSObject <CMAutoScorerProtocol>
@end

NS_ASSUME_NONNULL_END
