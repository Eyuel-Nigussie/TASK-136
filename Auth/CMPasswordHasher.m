//
//  CMPasswordHasher.m
//  CourierMatch
//

#import "CMPasswordHasher.h"
#import "CMKeychain.h"
#import "CMKeychainKeys.h"
@import CommonCrypto;
@import Security;
#import "CMDebugLogger.h"

NSUInteger const CMPasswordHasherDefaultIterations = 600000;
NSUInteger const CMPasswordHasherSaltLength        = 32;
NSUInteger const CMPasswordHasherHashLength        = CC_SHA256_DIGEST_LENGTH; // 32

static NSUInteger const kPepperLength        = 32;
static NSUInteger const kPBKDF2OutputLength  = 32;

@implementation CMPasswordHasher

+ (NSData *)generateSalt {
    NSMutableData *salt = [NSMutableData dataWithLength:CMPasswordHasherSaltLength];
    (void)SecRandomCopyBytes(kSecRandomDefault,
                             CMPasswordHasherSaltLength,
                             salt.mutableBytes);
    return salt;
}

+ (NSData *)pepper {
    NSError *err = nil;
    NSData *p = [CMKeychain ensureRandomBytesForKey:CMKeychainKey_AuthPepper
                                              length:kPepperLength
                                               error:&err];
    if (!p) {
        CMLogError(@"auth", @"pepper retrieval failed: %@", err);
    }
    return p;
}

+ (NSData *)pbkdf2:(NSString *)password salt:(NSData *)salt iterations:(NSUInteger)iters {
    NSData *pwData = [password dataUsingEncoding:NSUTF8StringEncoding];
    if (!pwData || !salt) { return nil; }
    NSMutableData *out = [NSMutableData dataWithLength:kPBKDF2OutputLength];
    int rc = CCKeyDerivationPBKDF(kCCPBKDF2,
                                  pwData.bytes, pwData.length,
                                  salt.bytes, salt.length,
                                  kCCPRFHmacAlgSHA512,
                                  (unsigned int)iters,
                                  out.mutableBytes, out.length);
    if (rc != kCCSuccess) {
        CMLogError(@"auth", @"PBKDF2 failed: %d", rc);
        return nil;
    }
    return out;
}

+ (NSData *)hmacSHA256Key:(NSData *)key data:(NSData *)data {
    NSMutableData *mac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           key.bytes, key.length,
           data.bytes, data.length,
           mac.mutableBytes);
    return mac;
}

+ (NSData *)hashPassword:(NSString *)password
                     salt:(NSData *)salt
              iterations:(NSUInteger)iterations {
    NSData *pep = [self pepper];
    if (!pep) { return nil; }
    NSData *derived = [self pbkdf2:password salt:salt iterations:iterations];
    if (!derived) { return nil; }
    return [self hmacSHA256Key:pep data:derived];
}

+ (BOOL)verifyPassword:(NSString *)password
                  salt:(NSData *)salt
            iterations:(NSUInteger)iterations
           expectedHash:(NSData *)expected {
    NSData *candidate = [self hashPassword:password salt:salt iterations:iterations];
    if (!candidate || !expected) { return NO; }
    if (candidate.length != expected.length) { return NO; }
    const unsigned char *a = candidate.bytes;
    const unsigned char *b = expected.bytes;
    unsigned char diff = 0;
    for (NSUInteger i = 0; i < candidate.length; i++) {
        diff |= (unsigned char)(a[i] ^ b[i]);
    }
    return diff == 0;
}

@end
