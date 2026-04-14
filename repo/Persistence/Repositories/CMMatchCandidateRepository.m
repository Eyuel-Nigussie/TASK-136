#import "CMMatchCandidateRepository.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMMatchCandidateRepository
+ (NSString *)entityName { return @"MatchCandidate"; }

- (CMMatchCandidate *)insertCandidate {
    CMMatchCandidate *c = (CMMatchCandidate *)[self insertStampedObject];
    if (!c.candidateId) c.candidateId = [[NSUUID UUID] UUIDString];
    return c;
}

- (NSArray<CMMatchCandidate *> *)candidatesForItinerary:(NSString *)itineraryId
                                               staleOnly:(BOOL)staleOnly
                                                   error:(NSError **)error {
    NSPredicate *p;
    if (staleOnly) {
        p = [NSPredicate predicateWithFormat:@"itineraryId == %@ AND stale == YES", itineraryId];
    } else {
        p = [NSPredicate predicateWithFormat:@"itineraryId == %@", itineraryId];
    }
    // Q4: deterministic sort — score DESC, detourMiles ASC, pickupWindowStart (through orderId), orderId ASC.
    NSArray *sorts = @[
        [NSSortDescriptor sortDescriptorWithKey:@"score"       ascending:NO],
        [NSSortDescriptor sortDescriptorWithKey:@"detourMiles" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"orderId"     ascending:YES],
    ];
    return [self fetchWithPredicate:p sortDescriptors:sorts limit:0 error:error];
}

- (CMMatchCandidate *)findByItineraryId:(NSString *)itineraryId
                                 orderId:(NSString *)orderId
                                   error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:
                      @"itineraryId == %@ AND orderId == %@", itineraryId, orderId];
    return [self fetchOneWithPredicate:p error:error];
}

- (BOOL)deleteAllForItinerary:(NSString *)itineraryId error:(NSError **)error {
    NSArray *all = [self candidatesForItinerary:itineraryId staleOnly:NO error:error];
    if (!all) return NO;
    for (CMMatchCandidate *c in all) {
        [self.context deleteObject:c];
    }
    return [self.context cm_saveWithError:error];
}
@end
