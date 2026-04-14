#import "CMRepository.h"
#import "CMItinerary.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMItineraryRepository : CMRepository
- (CMItinerary *)insertItinerary;
- (nullable CMItinerary *)findById:(NSString *)itineraryId error:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeItineraries:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeForCourierId:(NSString *)courierId error:(NSError **)error;
/// Background-safe: fetches all active itineraries across all tenants without
/// requiring an authenticated CMTenantContext. For BGTask use only.
- (nullable NSArray<CMItinerary *> *)allActiveItinerariesForBackground:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
