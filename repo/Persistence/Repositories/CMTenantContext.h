//
//  CMTenantContext.h
//  CourierMatch
//
//  Holds the (currentUser, currentTenant) pair. Every repository fetch MUST
//  scope by `currentTenantId`. See design.md §4.4.
//
//  The context is thread-safe for reads via an internal lock; writes are
//  expected from the SessionManager during login / logout.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const CMTenantContextDidChangeNotification;

@interface CMTenantContext : NSObject

+ (instancetype)shared;

@property (atomic, copy, readonly, nullable) NSString *currentUserId;
@property (atomic, copy, readonly, nullable) NSString *currentTenantId;
@property (atomic, copy, readonly, nullable) NSString *currentRole;

/// Called by SessionManager after successful auth.
- (void)setUserId:(NSString *)userId
         tenantId:(NSString *)tenantId
             role:(NSString *)role;

/// Called on logout or forced logout.
- (void)clear;

/// Returns YES iff a user is currently authenticated.
- (BOOL)isAuthenticated;

/// Convenience predicate returning `tenantId == %@`
/// bound to the current tenant. Returns nil if no tenant is set.
/// Use this for entities without `deletedAt` (e.g., AuditEntry).
- (nullable NSPredicate *)scopingPredicate;

/// Predicate returning `tenantId == %@ AND deletedAt == nil`.
/// Use for entities with soft-delete support.
- (nullable NSPredicate *)scopingPredicateWithSoftDelete;

@end

NS_ASSUME_NONNULL_END
