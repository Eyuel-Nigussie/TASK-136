//
//  CMTenantRepository.h
//  CourierMatch
//

#import "CMRepository.h"
#import "CMTenant.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMTenantRepository : CMRepository
- (CMTenant *)insertTenant;
- (nullable CMTenant *)findByTenantId:(NSString *)tenantId error:(NSError **)error;
- (nullable NSArray<CMTenant *> *)allActive:(NSError **)error;
/// Background-safe: fetches all active tenants without requiring authenticated
/// CMTenantContext. For BGTask use only.
- (nullable NSArray<CMTenant *> *)allActiveForBackground:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
