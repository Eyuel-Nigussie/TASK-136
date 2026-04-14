//
//  CMEncryptedValueTransformer.m
//  CourierMatch
//
//  AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC). Equivalent authenticated
//  encryption using only public CommonCrypto APIs.
//
//  Wire format: magic(4) | iv(16) | hmac(32) | ciphertext
//  The HMAC covers iv || ciphertext to provide integrity.
//

#import "CMEncryptedValueTransformer.h"
#import "CMKeychain.h"
#import "CMKeychainKeys.h"
#import "CMError.h"
#import "CMDebugLogger.h"
@import CommonCrypto;
@import Security;

NSValueTransformerName const CMEncryptedValueTransformerName = @"CMEncryptedValueTransformer";

static NSString * const kMagic = @"CME1";          // 4 bytes magic / version
static NSUInteger const kKeyLen   = 32;             // AES-256
static NSUInteger const kIVLen    = 16;             // CBC IV
static NSUInteger const kHMACLen  = 32;             // SHA-256

@implementation CMEncryptedValueTransformer

+ (Class)transformedValueClass { return [NSData class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

+ (void)registerTransformer {
    CMEncryptedValueTransformer *t = [CMEncryptedValueTransformer new];
    [NSValueTransformer setValueTransformer:t forName:CMEncryptedValueTransformerName];
}

+ (NSData *)fieldKey {
    NSError *err = nil;
    NSData *k = [CMKeychain ensureRandomBytesForKey:CMKeychainKey_FieldKey
                                             length:kKeyLen
                                              error:&err];
    if (!k) {
        CMLogError(@"crypto", @"field key retrieval failed: %@", err);
    }
    return k;
}

+ (NSData *)randomBytes:(NSUInteger)n {
    NSMutableData *b = [NSMutableData dataWithLength:n];
    SecRandomCopyBytes(kSecRandomDefault, n, b.mutableBytes);
    return b;
}

/// Derives two independent subkeys from the master key via HMAC:
/// encKey = HMAC-SHA256(masterKey, "enc"), macKey = HMAC-SHA256(masterKey, "mac").
+ (void)deriveEncKey:(NSData **)encKey macKey:(NSData **)macKey fromMaster:(NSData *)master {
    NSMutableData *ek = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    NSMutableData *mk = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    const char *encLabel = "enc";
    const char *macLabel = "mac";
    CCHmac(kCCHmacAlgSHA256, master.bytes, master.length,
           encLabel, strlen(encLabel), ek.mutableBytes);
    CCHmac(kCCHmacAlgSHA256, master.bytes, master.length,
           macLabel, strlen(macLabel), mk.mutableBytes);
    if (encKey) *encKey = ek;
    if (macKey) *macKey = mk;
}

- (id)transformedValue:(id)value {
    if (!value) { return nil; }
    NSData *plain = nil;
    if ([value isKindOfClass:[NSString class]]) {
        plain = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([value isKindOfClass:[NSData class]]) {
        plain = (NSData *)value;
    } else {
        return nil;
    }
    NSData *master = [CMEncryptedValueTransformer fieldKey];
    if (master.length < kKeyLen) { return nil; }

    NSData *encKey = nil, *macKey = nil;
    [CMEncryptedValueTransformer deriveEncKey:&encKey macKey:&macKey fromMaster:master];

    NSData *iv = [CMEncryptedValueTransformer randomBytes:kIVLen];

    // AES-256-CBC encrypt with PKCS7 padding.
    size_t bufLen = plain.length + kCCBlockSizeAES128;
    NSMutableData *cipher = [NSMutableData dataWithLength:bufLen];
    size_t moved = 0;
    CCCryptorStatus s = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                encKey.bytes, encKey.length,
                                iv.bytes,
                                plain.bytes, plain.length,
                                cipher.mutableBytes, bufLen, &moved);
    if (s != kCCSuccess) {
        CMLogError(@"crypto", @"CBC encrypt failed: %d", (int)s);
        return nil;
    }
    cipher.length = moved;

    // HMAC-SHA256(macKey, iv || ciphertext) for integrity.
    NSMutableData *hmacInput = [NSMutableData dataWithData:iv];
    [hmacInput appendData:cipher];
    NSMutableData *hmac = [NSMutableData dataWithLength:kHMACLen];
    CCHmac(kCCHmacAlgSHA256, macKey.bytes, macKey.length,
           hmacInput.bytes, hmacInput.length, hmac.mutableBytes);

    // Wire format: magic(4) | iv(16) | hmac(32) | ciphertext
    NSMutableData *out = [NSMutableData data];
    [out appendData:[kMagic dataUsingEncoding:NSASCIIStringEncoding]];
    [out appendData:iv];
    [out appendData:hmac];
    [out appendData:cipher];
    return out;
}

- (id)reverseTransformedValue:(id)value {
    if (![value isKindOfClass:[NSData class]]) { return nil; }
    NSData *blob = (NSData *)value;
    NSUInteger hdrLen = 4 + kIVLen + kHMACLen;
    if (blob.length < hdrLen) { return nil; }

    NSData *magic = [blob subdataWithRange:NSMakeRange(0, 4)];
    NSString *magicStr = [[NSString alloc] initWithData:magic encoding:NSASCIIStringEncoding];
    if (![magicStr isEqualToString:kMagic]) { return nil; }

    NSData *iv     = [blob subdataWithRange:NSMakeRange(4, kIVLen)];
    NSData *storedHMAC = [blob subdataWithRange:NSMakeRange(4 + kIVLen, kHMACLen)];
    NSData *cipher = [blob subdataWithRange:NSMakeRange(hdrLen, blob.length - hdrLen)];

    NSData *master = [CMEncryptedValueTransformer fieldKey];
    if (master.length < kKeyLen) { return nil; }

    NSData *encKey = nil, *macKey = nil;
    [CMEncryptedValueTransformer deriveEncKey:&encKey macKey:&macKey fromMaster:master];

    // Verify HMAC before decrypting (encrypt-then-MAC: verify first).
    NSMutableData *hmacInput = [NSMutableData dataWithData:iv];
    [hmacInput appendData:cipher];
    NSMutableData *computed = [NSMutableData dataWithLength:kHMACLen];
    CCHmac(kCCHmacAlgSHA256, macKey.bytes, macKey.length,
           hmacInput.bytes, hmacInput.length, computed.mutableBytes);

    // Constant-time comparison.
    const unsigned char *a = computed.bytes;
    const unsigned char *b = storedHMAC.bytes;
    unsigned char diff = 0;
    for (NSUInteger i = 0; i < kHMACLen; i++) { diff |= (unsigned char)(a[i] ^ b[i]); }
    if (diff != 0) {
        CMLogError(@"crypto", @"HMAC verification failed — integrity compromised");
        return nil;
    }

    // AES-256-CBC decrypt.
    size_t bufLen = cipher.length + kCCBlockSizeAES128;
    NSMutableData *plain = [NSMutableData dataWithLength:bufLen];
    size_t moved = 0;
    CCCryptorStatus s = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                encKey.bytes, encKey.length,
                                iv.bytes,
                                cipher.bytes, cipher.length,
                                plain.mutableBytes, bufLen, &moved);
    if (s != kCCSuccess) {
        CMLogError(@"crypto", @"CBC decrypt failed: %d", (int)s);
        return nil;
    }
    plain.length = moved;
    return plain;
}

@end
