//
//  CMAccountService.h
//  CourierMatch
//
//  Service-layer account deletion with authorization enforcement.
//  Biometric re-auth is the caller's responsibility (UI layer) before
//  invoking deleteAccount:. This service enforces admin role, prevents
//  self-deletion, performs soft-delete, and writes the audit trail.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMUserAccount;

NS_ASSUME_NONNULL_BEGIN

@interface CMAccountService : NSObject

- (instancetype)initWithContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Soft-deletes a user account. Enforces admin role, prevents self-deletion,
/// sets status to deleted + forceLogoutAt, and writes audit entry.
/// Caller MUST perform biometric re-auth before invoking this method.
/// @param user  The user account to delete.
/// @param error Set on failure (permission denied, self-deletion, save error).
/// @return YES on success, NO on failure.
- (BOOL)deleteAccount:(CMUserAccount *)user error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
