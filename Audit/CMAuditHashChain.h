//
//  CMAuditHashChain.h
//  CourierMatch
//
//  Core hash-chain logic for append-only audit entries.
//  Uses HMAC-SHA256 with per-tenant Keychain-stored seeds.
//  See design.md §10.3 and questions.md Q8.
//

#import <Foundation/Foundation.h>

@class CMAuditEntry;

NS_ASSUME_NONNULL_BEGIN

@interface CMAuditHashChain : NSObject

/// Returns a deterministic JSON representation of the entry's auditable fields.
/// Keys are sorted alphabetically, serialized as compact UTF-8, no whitespace.
+ (NSData *)canonicalJSONForEntry:(CMAuditEntry *)entry;

/// Computes HMAC-SHA256(tenantSeed, prevHash || canonicalJSON(entry)).
/// @param entry The audit entry whose fields will be canonicalized.
/// @param prevHash The hash of the previous entry in the chain (nil for the first entry).
/// @param tenantSeed The per-tenant HMAC seed from the Keychain.
/// @return The computed 32-byte hash.
+ (NSData *)computeHashForEntry:(CMAuditEntry *)entry
                       prevHash:(nullable NSData *)prevHash
                     tenantSeed:(NSData *)tenantSeed;

/// Ensures a 32-byte random seed exists in the Keychain for the given tenant.
/// Key: "cm.audit.seed.<tenantId>". Uses kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
/// @return The seed data, or nil on failure.
+ (nullable NSData *)ensureSeedForTenant:(NSString *)tenantId error:(NSError **)error;

/// Ensures the device-wide meta-chain seed exists in the Keychain.
/// Key: "cm.audit.meta". This seed is NOT deletable through any in-app flow.
/// @return The meta seed data, or nil on failure.
+ (nullable NSData *)ensureMetaSeed:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
