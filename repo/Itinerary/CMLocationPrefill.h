//
//  CMLocationPrefill.h
//  CourierMatch
//
//  Location-based origin prefill using reduced accuracy per Q14.
//  Stops updates on background entry. Prefills city, state, ZIP only
//  (line1 is left blank, labeled "approximate location").
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMLocationPrefill : NSObject

/// Requests a single reduced-accuracy location fix and reverse-geocodes
/// approximate city, state, and ZIP. Line1 is intentionally left blank.
///
/// The completion is called on the main queue.
/// On success, city/state/zip are non-nil (but may be empty if unavailable).
/// On failure, error is set.
- (void)requestPrefillWithCompletion:(void (^)(NSString * _Nullable city,
                                               NSString * _Nullable state,
                                               NSString * _Nullable zip,
                                               NSError * _Nullable error))completion;

/// Call to explicitly stop location updates early (e.g., if the user dismisses
/// the form before a fix is received).
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
