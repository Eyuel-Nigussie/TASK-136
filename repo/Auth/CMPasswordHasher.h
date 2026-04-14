//
//  CMPasswordHasher.h
//  CourierMatch
//
//  PBKDF2-SHA512 @ 600,000 iterations with per-user 32-byte salt and a
//  Keychain-held 32-byte pepper — outer HMAC-SHA256 over the PBKDF2 output.
//  See design.md §4.1 and questions.md Q1.
//
//  Stored hash shape (64 bytes):
//      stored = HMAC-SHA256(pepper, PBKDF2-SHA512(password, salt, iters, 32))
//  Iterations are stored per-record to permit future migration upward
//  without breaking existing accounts.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSUInteger const CMPasswordHasherDefaultIterations;
extern NSUInteger const CMPasswordHasherSaltLength;    // 32
extern NSUInteger const CMPasswordHasherHashLength;    // 32 (HMAC-SHA256 output)

@interface CMPasswordHasher : NSObject

/// Returns a cryptographically random salt of `CMPasswordHasherSaltLength` bytes.
+ (NSData *)generateSalt;

/// Derives the stored hash. Returns nil if the pepper cannot be loaded.
+ (nullable NSData *)hashPassword:(NSString *)password
                             salt:(NSData *)salt
                       iterations:(NSUInteger)iterations;

/// Constant-time verification.
+ (BOOL)verifyPassword:(NSString *)password
                  salt:(NSData *)salt
            iterations:(NSUInteger)iterations
           expectedHash:(NSData *)expected;

@end

NS_ASSUME_NONNULL_END
