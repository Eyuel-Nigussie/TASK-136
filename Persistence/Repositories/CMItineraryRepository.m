#import "CMItineraryRepository.h"

@implementation CMItineraryRepository
+ (NSString *)entityName { return @"Itinerary"; }

- (CMItinerary *)insertItinerary {
    CMItinerary *i = (CMItinerary *)[self insertStampedObject];
    if (!i.itineraryId) i.itineraryId = [[NSUUID UUID] UUIDString];
    return i;
}
- (CMItinerary *)findById:(NSString *)itineraryId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"itineraryId == %@", itineraryId] error:error];
}
- (NSArray<CMItinerary *> *)activeItineraries:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"status == %@", CMItineraryStatusActive];
    return [self fetchWithPredicate:p sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"departureWindowStart" ascending:YES]] limit:0 error:error];
}
- (NSArray<CMItinerary *> *)activeForCourierId:(NSString *)courierId error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"courierId == %@ AND status == %@", courierId, CMItineraryStatusActive];
    return [self fetchWithPredicate:p sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"departureWindowStart" ascending:YES]] limit:0 error:error];
}
@end
