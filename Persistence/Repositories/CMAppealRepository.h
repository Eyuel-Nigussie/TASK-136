#import "CMRepository.h"
#import "CMAppeal.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAppealRepository : CMRepository
- (CMAppeal *)insertAppeal;
- (nullable CMAppeal *)findById:(NSString *)appealId error:(NSError **)error;
- (nullable NSArray<CMAppeal *> *)appealsForScorecard:(NSString *)scorecardId error:(NSError **)error;
- (nullable NSArray<CMAppeal *> *)pendingAppeals:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
