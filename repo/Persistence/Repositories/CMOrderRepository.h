//
//  CMOrderRepository.h
//  CourierMatch
//

#import "CMRepository.h"
#import "CMOrder.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMOrderRepository : CMRepository
- (CMOrder *)insertOrder;
- (nullable CMOrder *)findByOrderId:(NSString *)orderId error:(NSError **)error;
- (nullable CMOrder *)findByExternalRef:(NSString *)ref error:(NSError **)error;
- (nullable NSArray<CMOrder *> *)ordersWithStatus:(NSString *)status
                                            limit:(NSUInteger)limit
                                            error:(NSError **)error;
/// Spatio-temporal pre-filter for match engine (Q17).
- (nullable NSArray<CMOrder *> *)candidateOrdersForWindowStart:(NSDate *)start
                                                     windowEnd:(NSDate *)end
                                                         limit:(NSUInteger)limit
                                                         error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
