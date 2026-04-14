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
@end
