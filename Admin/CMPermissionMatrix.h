//
//  CMPermissionMatrix.h
//  CourierMatch
//
//  Runtime RBAC enforcement backed by PermissionMatrix.plist.
//  Singleton that loads the role -> allowed-actions map at init and
//  provides predicate-based permission checks for controllers.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMPermissionMatrix : NSObject

+ (instancetype)shared;

/// Returns YES if the given role is permitted to perform the named action.
- (BOOL)hasPermission:(NSString *)action forRole:(NSString *)role;

/// Returns the full list of allowed action strings for the given role.
- (NSArray<NSString *> *)allowedActionsForRole:(NSString *)role;

@end

NS_ASSUME_NONNULL_END
