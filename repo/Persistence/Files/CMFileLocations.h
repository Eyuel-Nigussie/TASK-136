//
//  CMFileLocations.h
//  CourierMatch
//
//  Sandbox path helpers. Ownership boundaries (tenantId path scoping) are
//  enforced centrally here so repositories cannot escape via traversal.
//  See design.md §11.3, §16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMFileLocations : NSObject

/// `Library/Application Support/CourierMatch/` — core data parent.
+ (NSURL *)appSupportDirectoryCreatingIfNeeded:(BOOL)create;

/// Main Core Data store file (NSFileProtectionComplete).
+ (NSURL *)mainStoreURL;

/// Sidecar "work" Core Data store file (NSFileProtectionCompleteUntilFirstUserAuthentication).
/// Q7: holds cleanup-only metadata so background tasks can run while device is locked.
+ (NSURL *)sidecarStoreURL;

/// `Documents/attachments/{tenantId}/` — tenantId is sanitized to be path-safe.
/// Returns nil only if tenantId is empty or entirely non-alphanumeric.
+ (nullable NSURL *)attachmentsDirectoryForTenantId:(NSString *)tenantId
                                   createIfNeeded:(BOOL)create;

/// Returns a path-safe version of a tenant ID (alphanumeric + hyphen only).
+ (nullable NSString *)sanitizedPathComponent:(NSString *)input;

/// `Caches/attachment-thumbs/` — evicted on memory warning.
+ (NSURL *)thumbnailCacheDirectoryCreatingIfNeeded:(BOOL)create;

/// `Caches/debug-log/` — ring-buffer backing store.
+ (NSURL *)debugLogDirectoryCreatingIfNeeded:(BOOL)create;

@end

NS_ASSUME_NONNULL_END
