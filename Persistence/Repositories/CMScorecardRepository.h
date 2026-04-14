#import "CMRepository.h"
#import "CMDeliveryScorecard.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMScorecardRepository : CMRepository
- (CMDeliveryScorecard *)insertScorecard;
- (nullable CMDeliveryScorecard *)findById:(NSString *)scorecardId error:(NSError **)error;
- (nullable CMDeliveryScorecard *)findForOrder:(NSString *)orderId error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
