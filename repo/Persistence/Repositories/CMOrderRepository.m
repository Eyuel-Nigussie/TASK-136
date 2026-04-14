#import "CMOrderRepository.h"

@implementation CMOrderRepository

+ (NSString *)entityName { return @"Order"; }

- (CMOrder *)insertOrder {
    CMOrder *o = (CMOrder *)[self insertStampedObject];
    if (!o.orderId) o.orderId = [[NSUUID UUID] UUIDString];
    return o;
}

- (CMOrder *)findByOrderId:(NSString *)orderId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"orderId == %@", orderId] error:error];
}

- (CMOrder *)findByExternalRef:(NSString *)ref error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"externalOrderRef == %@", ref] error:error];
}

- (NSArray<CMOrder *> *)ordersWithStatus:(NSString *)status
                                    limit:(NSUInteger)limit
                                    error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"status == %@", status];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"pickupWindowStart" ascending:YES];
    return [self fetchWithPredicate:p sortDescriptors:@[sort] limit:limit error:error];
}

- (NSArray<CMOrder *> *)candidateOrdersForWindowStart:(NSDate *)start
                                            windowEnd:(NSDate *)end
                                                limit:(NSUInteger)limit
                                                error:(NSError **)error {
    // Q17: ±24h temporal pre-filter. The spatial bounding-box filter is
    // applied in-memory by CMMatchEngine after this fetch because lat/lng
    // live inside a transformable CMAddress (not indexed by Core Data).
    NSPredicate *p = [NSPredicate predicateWithFormat:
                      @"pickupWindowStart <= %@ AND pickupWindowEnd >= %@ "
                       "AND (status == %@ OR status == %@)",
                      end, start,
                      CMOrderStatusNew, CMOrderStatusAssigned];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"pickupWindowStart" ascending:YES];
    return [self fetchWithPredicate:p sortDescriptors:@[sort] limit:limit error:error];
}

@end
