//
//  CMKeychain.m
//  CourierMatch
//

#import "CMKeychain.h"
#import "CMKeychainKeys.h"
#import "CMError.h"
#import <Security/Security.h>

@implementation CMKeychain

+ (NSMutableDictionary *)baseQueryForKey:(NSString *)key {
    return [@{
        (__bridge id)kSecClass:        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:  CMKeychainService,
        (__bridge id)kSecAttrAccount:  key ?: @"",
    } mutableCopy];
}

+ (BOOL)setData:(NSData *)data forKey:(NSString *)key error:(NSError **)error {
    if (!data || !key) {
        if (error) { *error = [CMError errorWithCode:CMErrorCodeKeychainOperationFailed
                                              message:@"Nil data or key"]; }
        return NO;
    }
    NSMutableDictionary *q = [self baseQueryForKey:key];
    // Try update first.
    NSDictionary *attrs = @{
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    };
    OSStatus s = SecItemUpdate((__bridge CFDictionaryRef)q,
                               (__bridge CFDictionaryRef)attrs);
    if (s == errSecItemNotFound) {
        NSMutableDictionary *add = [q mutableCopy];
        [add addEntriesFromDictionary:attrs];
        s = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    }
    if (s != errSecSuccess) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeKeychainOperationFailed
                                    message:[NSString stringWithFormat:@"SecItem status %d", (int)s]];
        }
        return NO;
    }
    return YES;
}

+ (NSData *)dataForKey:(NSString *)key error:(NSError **)error {
    NSMutableDictionary *q = [self baseQueryForKey:key];
    q[(__bridge id)kSecReturnData]    = @YES;
    q[(__bridge id)kSecMatchLimit]    = (__bridge id)kSecMatchLimitOne;
    CFTypeRef out = NULL;
    OSStatus s = SecItemCopyMatching((__bridge CFDictionaryRef)q, &out);
    if (s == errSecItemNotFound) {
        return nil;
    }
    if (s != errSecSuccess) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeKeychainOperationFailed
                                    message:[NSString stringWithFormat:@"SecItem lookup status %d", (int)s]];
        }
        return nil;
    }
    NSData *data = (__bridge_transfer NSData *)out;
    return data;
}

+ (BOOL)deleteKey:(NSString *)key error:(NSError **)error {
    NSMutableDictionary *q = [self baseQueryForKey:key];
    OSStatus s = SecItemDelete((__bridge CFDictionaryRef)q);
    if (s != errSecSuccess && s != errSecItemNotFound) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeKeychainOperationFailed
                                    message:[NSString stringWithFormat:@"SecItem delete status %d", (int)s]];
        }
        return NO;
    }
    return YES;
}

+ (NSData *)ensureRandomBytesForKey:(NSString *)key
                             length:(NSUInteger)length
                              error:(NSError **)error {
    NSData *existing = [self dataForKey:key error:NULL];
    if (existing && existing.length >= length) {
        return existing;
    }
    NSMutableData *buf = [NSMutableData dataWithLength:length];
    int rc = SecRandomCopyBytes(kSecRandomDefault, length, buf.mutableBytes);
    if (rc != errSecSuccess) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeCryptoOperationFailed
                                    message:@"SecRandomCopyBytes failed"];
        }
        return nil;
    }
    if (![self setData:buf forKey:key error:error]) {
        return nil;
    }
    return buf;
}

@end
