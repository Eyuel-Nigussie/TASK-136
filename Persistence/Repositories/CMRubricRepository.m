#import "CMRubricRepository.h"

@implementation CMRubricRepository
+ (NSString *)entityName { return @"RubricTemplate"; }

- (CMRubricTemplate *)insertRubric {
    CMRubricTemplate *r = (CMRubricTemplate *)[self insertStampedObject];
    if (!r.rubricId) r.rubricId = [[NSUUID UUID] UUIDString];
    return r;
}
- (CMRubricTemplate *)findById:(NSString *)rubricId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"rubricId == %@", rubricId] error:error];
}
- (CMRubricTemplate *)activeRubricForTenant:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"active == YES"];
    NSArray *sorts = @[[NSSortDescriptor sortDescriptorWithKey:@"rubricVersion" ascending:NO]];
    NSArray *r = [self fetchWithPredicate:p sortDescriptors:sorts limit:1 error:error];
    return r.firstObject;
}
- (CMRubricTemplate *)findById:(NSString *)rubricId rubricVersion:(int64_t)v error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"rubricId == %@ AND rubricVersion == %lld", rubricId, v];
    return [self fetchOneWithPredicate:p error:error];
}
@end
