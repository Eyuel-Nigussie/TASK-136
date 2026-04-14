#import "CMTenantRepository.h"
@implementation CMTenantRepository
+ (NSString *)entityName { return @"Tenant"; }
- (CMTenant *)insertTenant {
    CMTenant *t = (CMTenant *)[self insertStampedObject];
    if (!t.tenantId) t.tenantId = [[NSUUID UUID] UUIDString];
    return t;
}
- (CMTenant *)findByTenantId:(NSString *)tenantId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"tenantId == %@", tenantId] error:error];
}
- (NSArray<CMTenant *> *)allActive:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"status == %@", CMTenantStatusActive];
    return [self fetchWithPredicate:p sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]] limit:0 error:error];
}

- (NSArray<CMTenant *> *)allActiveForBackground:(NSError **)error {
    // Direct fetch without CMTenantContext auth gate — for BGTask use only.
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Tenant"];
    req.predicate = [NSPredicate predicateWithFormat:@"status == %@ AND deletedAt == nil", CMTenantStatusActive];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    return [self.context executeFetchRequest:req error:error];
}
@end
