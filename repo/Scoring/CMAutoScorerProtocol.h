//
//  CMAutoScorerProtocol.h
//  CourierMatch
//
//  Protocol for automatic scoring evaluators. Each evaluator inspects an order
//  and its attachments to produce a deterministic score result.
//  See design.md §9.2.
//

#import <Foundation/Foundation.h>

@class CMOrder;
@class CMAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Keys used in the result dictionary returned by automatic scorers.
extern NSString * const CMAutoScorerResultPointsKey;    // NSNumber (double)
extern NSString * const CMAutoScorerResultMaxPointsKey;  // NSNumber (double)
extern NSString * const CMAutoScorerResultEvidenceKey;   // NSString

/// Protocol that all automatic scorers must conform to.
/// Implementations must be stateless and deterministic.
@protocol CMAutoScorerProtocol <NSObject>

/// Evaluate the scorer against an order and its associated attachments.
/// @param order       The delivery order being scored.
/// @param attachments Array of CMAttachment objects for this order.
/// @param error       Set on evaluation failure (NOT for a zero score — that is a valid result).
/// @return Dictionary with keys CMAutoScorerResultPointsKey, CMAutoScorerResultMaxPointsKey,
///         and CMAutoScorerResultEvidenceKey. Nil only on error.
- (nullable NSDictionary *)evaluateForOrder:(CMOrder *)order
                                attachments:(NSArray<CMAttachment *> *)attachments
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
