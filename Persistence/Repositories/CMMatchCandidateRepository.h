#import "CMRepository.h"
#import "CMMatchCandidate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMMatchCandidateRepository : CMRepository
- (CMMatchCandidate *)insertCandidate;
- (nullable NSArray<CMMatchCandidate *> *)candidatesForItinerary:(NSString *)itineraryId
                                                        staleOnly:(BOOL)staleOnly
                                                            error:(NSError **)error;
- (nullable CMMatchCandidate *)findByItineraryId:(NSString *)itineraryId
                                          orderId:(NSString *)orderId
                                            error:(NSError **)error;
- (BOOL)deleteAllForItinerary:(NSString *)itineraryId error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
