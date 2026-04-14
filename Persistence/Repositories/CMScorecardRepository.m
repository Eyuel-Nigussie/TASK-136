#import "CMScorecardRepository.h"

@implementation CMScorecardRepository
+ (NSString *)entityName { return @"DeliveryScorecard"; }

- (CMDeliveryScorecard *)insertScorecard {
    CMDeliveryScorecard *s = (CMDeliveryScorecard *)[self insertStampedObject];
    if (!s.scorecardId) s.scorecardId = [[NSUUID UUID] UUIDString];
    return s;
}
- (CMDeliveryScorecard *)findById:(NSString *)scorecardId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"scorecardId == %@", scorecardId] error:error];
}
- (CMDeliveryScorecard *)findForOrder:(NSString *)orderId error:(NSError **)error {
    // Return the latest scorecard (highest version / most recent creation).
    NSPredicate *p = [NSPredicate predicateWithFormat:@"orderId == %@", orderId];
    NSArray *sorts = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
    NSArray *r = [self fetchWithPredicate:p sortDescriptors:sorts limit:1 error:error];
    return r.firstObject;
}
@end
