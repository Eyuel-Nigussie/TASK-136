#import "CMRepository.h"
#import "CMItinerary.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMItineraryRepository : CMRepository
- (CMItinerary *)insertItinerary;
- (nullable CMItinerary *)findById:(NSString *)itineraryId error:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeItineraries:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeForCourierId:(NSString *)courierId error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
