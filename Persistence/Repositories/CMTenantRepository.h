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
@end

NS_ASSUME_NONNULL_END
