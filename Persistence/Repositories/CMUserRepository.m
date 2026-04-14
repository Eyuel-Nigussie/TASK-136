//
//  CMUserRepository.m
//  CourierMatch
//

#import "CMUserRepository.h"
#import "CMTenantContext.h"

@implementation CMUserRepository

+ (NSString *)entityName { return @"UserAccount"; }

- (CMUserAccount *)insertUser {
    CMUserAccount *u = (CMUserAccount *)[self insertStampedObject];
    if (!u.userId) { u.userId = [[NSUUID UUID] UUIDString]; }
    return u;
}

- (CMUserAccount *)findByUserId:(NSString *)userId error:(NSError **)error {
    if (userId.length == 0) { return nil; }
    NSPredicate *p = [NSPredicate predicateWithFormat:@"userId == %@", userId];
    return [self fetchOneWithPredicate:p error:error];
}

- (CMUserAccount *)preAuthLookupWithTenantId:(NSString *)tenantId
                                    username:(NSString *)username
                                       error:(NSError **)error {
    if (tenantId.length == 0 || username.length == 0) { return nil; }
    // Pre-auth path: cannot use self.scopedFetchRequest because TenantContext
    // is not yet set. Build a raw fetch scoped by the tenantId the user typed.
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:[[self class] entityName]];
    req.predicate = [NSPredicate predicateWithFormat:
                     @"tenantId == %@ AND username ==[c] %@ AND deletedAt == nil",
                     tenantId, username];
    req.fetchLimit = 1;
    NSError *err = nil;
    NSArray *r = [self.context executeFetchRequest:req error:&err];
    if (err && error) { *error = err; }
    return r.firstObject;
}

- (NSArray<CMUserAccount *> *)searchByUsernamePrefix:(NSString *)prefix
                                                limit:(NSUInteger)limit
                                                error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"username BEGINSWITH[c] %@", prefix ?: @""];
    NSArray *sorts = @[[NSSortDescriptor sortDescriptorWithKey:@"username" ascending:YES]];
    return [self fetchWithPredicate:p sortDescriptors:sorts limit:limit error:error];
}

@end
