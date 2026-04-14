//
//  CMIDMasker.h
//  CourierMatch
//
//  Masked display for sensitive identifiers. See design.md §8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMIDMasker : NSObject

/// Generic "keep last N digits" mask, padding with '*'.
/// Example: `maskTrailing:@"123456789" visibleTail:4` → `"*****6789"`.
+ (NSString *)maskTrailing:(NSString *)value visibleTail:(NSUInteger)tail;

/// SSN-style mask: `"***-**-1234"`.
+ (NSString *)ssnStyle:(NSString *)value;

/// Email: `"****@domain.com"` — preserves the domain.
+ (NSString *)emailStyle:(NSString *)value;

/// US phone (digits only input); returns `"(***) ***-NN-NN"` with last 4 preserved.
+ (NSString *)phoneStyle:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
