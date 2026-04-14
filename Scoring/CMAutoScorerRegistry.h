//
//  CMAutoScorerRegistry.h
//  CourierMatch
//
//  Extensible registry mapping evaluator keys (e.g., "on_time_within_10min")
//  to scorer instances conforming to CMAutoScorerProtocol.
//  New evaluators can be registered without engine changes.
//  See design.md §9.
//

#import <Foundation/Foundation.h>
#import "CMAutoScorerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAutoScorerRegistry : NSObject

/// Shared singleton registry. Built-in scorers are registered on first access.
+ (instancetype)shared;

/// Register a scorer for a given evaluator key.
/// Overwrites any previously registered scorer for the same key.
/// @param scorer Object conforming to CMAutoScorerProtocol.
/// @param key    The evaluator key string (e.g., "on_time_within_10min").
- (void)registerScorer:(id<CMAutoScorerProtocol>)scorer forKey:(NSString *)key;

/// Retrieve the scorer registered for a given key.
/// @param key The evaluator key string.
/// @return The scorer, or nil if no scorer is registered for the key.
- (nullable id<CMAutoScorerProtocol>)scorerForKey:(NSString *)key;

/// Returns all registered evaluator keys.
- (NSArray<NSString *> *)allKeys;

@end

NS_ASSUME_NONNULL_END
