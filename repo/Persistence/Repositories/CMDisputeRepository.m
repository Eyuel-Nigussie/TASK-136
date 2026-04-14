#import "CMDisputeRepository.h"

@implementation CMDisputeRepository
+ (NSString *)entityName { return @"Dispute"; }

- (CMDispute *)insertDispute {
    CMDispute *d = (CMDispute *)[self insertStampedObject];
    if (!d.disputeId) d.disputeId = [[NSUUID UUID] UUIDString];
    return d;
}
- (CMDispute *)findById:(NSString *)disputeId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"disputeId == %@", disputeId] error:error];
}
- (NSArray<CMDispute *> *)openDisputes:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"status == %@ OR status == %@",
                      CMDisputeStatusOpen, CMDisputeStatusInReview];
    return [self fetchWithPredicate:p
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"openedAt" ascending:NO]]
                              limit:0 error:error];
}
- (NSArray<CMDispute *> *)disputesForOrder:(NSString *)orderId error:(NSError **)error {
    return [self fetchWithPredicate:[NSPredicate predicateWithFormat:@"orderId == %@", orderId]
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"openedAt" ascending:NO]]
                              limit:0 error:error];
}
@end
