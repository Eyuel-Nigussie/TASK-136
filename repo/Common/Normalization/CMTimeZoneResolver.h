//
//  CMTimeZoneResolver.h
//  CourierMatch
//
//  Resolves ZIP → IANA time zone per questions.md Q15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMTimeZoneResolver : NSObject

+ (instancetype)shared;

/// Returns a non-nil NSTimeZone. Unknown ZIP → device's current zone.
- (NSTimeZone *)timeZoneForZip:(nullable NSString *)zip;

/// Returns the IANA identifier matching the table lookup, or nil if unknown.
- (nullable NSString *)identifierForZip:(nullable NSString *)zip;

@end

NS_ASSUME_NONNULL_END
