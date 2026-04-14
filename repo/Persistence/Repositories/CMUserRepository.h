//
//  CMUserRepository.h
//  CourierMatch
//
//  CMRepository concrete subclass for UserAccount.
//  Admin-only / login flows need pre-authentication lookups by username, so
//  this repository exposes BOTH tenant-scoped fetches (via the base class)
//  AND a login-lookup path that bypasses the scope predicate. The latter is
//  marked explicitly and must only be used by CMAuthService during sign-in.
//

#import "CMRepository.h"
#import "CMUserAccount.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMUserRepository : CMRepository

/// Creates a NEW user record. Pre-stamps createdAt/updatedAt/version etc.
/// Caller sets username/password/role before saving.
- (CMUserAccount *)insertUser;

/// Tenant-scoped lookup by userId.
- (nullable CMUserAccount *)findByUserId:(NSString *)userId error:(NSError **)error;

/// **Login-time lookup**. Searches across all tenants for `tenantName`
/// and `username`, because the user is not yet authenticated and therefore
/// has no active tenant context. Case-insensitive on username.
- (nullable CMUserAccount *)preAuthLookupWithTenantId:(NSString *)tenantId
                                             username:(NSString *)username
                                                error:(NSError **)error;

/// Admin-only tenant-scoped search.
- (nullable NSArray<CMUserAccount *> *)searchByUsernamePrefix:(NSString *)prefix
                                                         limit:(NSUInteger)limit
                                                         error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
