#import "CMAppealRepository.h"

@implementation CMAppealRepository
+ (NSString *)entityName { return @"Appeal"; }

- (CMAppeal *)insertAppeal {
    CMAppeal *a = (CMAppeal *)[self insertStampedObject];
    if (!a.appealId) a.appealId = [[NSUUID UUID] UUIDString];
    return a;
}
- (CMAppeal *)findById:(NSString *)appealId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"appealId == %@", appealId] error:error];
}
- (NSArray<CMAppeal *> *)appealsForScorecard:(NSString *)scorecardId error:(NSError **)error {
    return [self fetchWithPredicate:[NSPredicate predicateWithFormat:@"scorecardId == %@", scorecardId]
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"openedAt" ascending:NO]]
                              limit:0 error:error];
}
- (NSArray<CMAppeal *> *)pendingAppeals:(NSError **)error {
    return [self fetchWithPredicate:[NSPredicate predicateWithFormat:@"decision == nil"]
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"openedAt" ascending:YES]]
                              limit:0 error:error];
}
@end
