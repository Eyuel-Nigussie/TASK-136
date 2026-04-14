//
//  CMKeychain.h
//  CourierMatch
//
//  Thin wrapper over Security.framework SecItem APIs.
//  Every item is pinned to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
//  per design.md §3.3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMKeychain : NSObject

+ (BOOL)setData:(NSData *)data forKey:(NSString *)key error:(NSError **)error;
+ (nullable NSData *)dataForKey:(NSString *)key error:(NSError **)error;
+ (BOOL)deleteKey:(NSString *)key error:(NSError **)error;

/// Ensures the given key exists with at least `length` bytes. If not, generates
/// cryptographically-random bytes via `SecRandomCopyBytes` and stores them.
/// Returns the ensured-present value.
+ (nullable NSData *)ensureRandomBytesForKey:(NSString *)key
                                       length:(NSUInteger)length
                                        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
