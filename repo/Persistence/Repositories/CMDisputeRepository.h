#import "CMRepository.h"
#import "CMDispute.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMDisputeRepository : CMRepository
- (CMDispute *)insertDispute;
- (nullable CMDispute *)findById:(NSString *)disputeId error:(NSError **)error;
- (nullable NSArray<CMDispute *> *)openDisputes:(NSError **)error;
- (nullable NSArray<CMDispute *> *)disputesForOrder:(NSString *)orderId error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
