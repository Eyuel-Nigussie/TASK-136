//
//  CMAddressNormalizer.h
//  CourierMatch
//
//  Address data-quality rules per design.md §7.1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMNormalizedAddress : NSObject
@property (nonatomic, copy, nullable) NSString *line1;
@property (nonatomic, copy, nullable) NSString *line2;
@property (nonatomic, copy, nullable) NSString *city;
@property (nonatomic, copy, nullable) NSString *stateAbbr;   // two-letter
@property (nonatomic, copy, nullable) NSString *zip;         // 5 or 5+4
@property (nonatomic, copy)           NSString *normalizedKey;
@end

@interface CMAddressNormalizer : NSObject

+ (instancetype)shared;

/// Returns a normalized copy with state → USPS 2-letter, ZIP validated, city
/// Title-cased, and `normalizedKey` computed. Returns nil if required fields
/// are unrecoverable.
- (nullable CMNormalizedAddress *)normalizeLine1:(nullable NSString *)line1
                                           line2:(nullable NSString *)line2
                                            city:(nullable NSString *)city
                                            state:(nullable NSString *)state
                                             zip:(nullable NSString *)zip;

/// Returns YES iff zip matches `^\d{5}(-\d{4})?$`.
- (BOOL)isValidZip:(nullable NSString *)zip;

/// Returns the two-letter USPS abbreviation, or uppercased input if already 2 chars.
- (nullable NSString *)stateAbbrFromInput:(nullable NSString *)input;

@end

NS_ASSUME_NONNULL_END
