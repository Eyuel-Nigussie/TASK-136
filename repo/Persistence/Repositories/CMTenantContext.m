//
//  CMTenantContext.m
//  CourierMatch
//

#import "CMTenantContext.h"

NSNotificationName const CMTenantContextDidChangeNotification = @"CMTenantContextDidChangeNotification";

@interface CMTenantContext ()
@property (atomic, copy, readwrite, nullable) NSString *currentUserId;
@property (atomic, copy, readwrite, nullable) NSString *currentTenantId;
@property (atomic, copy, readwrite, nullable) NSString *currentRole;
@end

@implementation CMTenantContext

+ (instancetype)shared {
    static CMTenantContext *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMTenantContext new]; });
    return s;
}

- (void)setUserId:(NSString *)userId tenantId:(NSString *)tenantId role:(NSString *)role {
    self.currentUserId   = [userId copy];
    self.currentTenantId = [tenantId copy];
    self.currentRole     = [role copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:CMTenantContextDidChangeNotification
                                                        object:self];
}

- (void)clear {
    self.currentUserId = nil;
    self.currentTenantId = nil;
    self.currentRole = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:CMTenantContextDidChangeNotification
                                                        object:self];
}

- (BOOL)isAuthenticated {
    return self.currentUserId.length > 0 && self.currentTenantId.length > 0;
}

- (NSPredicate *)scopingPredicate {
    NSString *tid = self.currentTenantId;
    if (!tid) { return nil; }
    return [NSPredicate predicateWithFormat:@"tenantId == %@", tid];
}

- (NSPredicate *)scopingPredicateWithSoftDelete {
    NSString *tid = self.currentTenantId;
    if (!tid) { return nil; }
    return [NSPredicate predicateWithFormat:@"tenantId == %@ AND deletedAt == nil", tid];
}

@end
