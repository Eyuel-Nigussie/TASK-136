//
//  CMKeychainKeys.h
//  CourierMatch
//
//  Named Keychain item identifiers. See design.md §3.3, §15, questions.md Q1/Q8.
//  All items are stored with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//  unless explicitly noted otherwise.
//

#ifndef CMKeychainKeys_h
#define CMKeychainKeys_h

#import <Foundation/Foundation.h>

/// Shared service identifier used for every SecItem query.
extern NSString * const CMKeychainService;

/// 32-byte PBKDF2 pepper, generated once on first launch (Q1).
extern NSString * const CMKeychainKey_AuthPepper;

/// AES-256 key used by CMEncryptedValueTransformer for flagged columns.
extern NSString * const CMKeychainKey_FieldKey;

/// Device-wide audit meta-chain HMAC seed (Q8). Never deletable through in-app flow.
extern NSString * const CMKeychainKey_AuditMetaSeed;

/// Per-tenant audit chain HMAC seed. Full account key is built via
///     `CMKeychainKey_AuditSeedPrefix + tenantId`.
extern NSString * const CMKeychainKey_AuditSeedPrefix;

/// Per-user session re-issue token (used by biometric unlock). Prefix + userId.
extern NSString * const CMKeychainKey_SessionTokenPrefix;

#endif /* CMKeychainKeys_h */
