#import "CMRepository.h"
#import "CMRubricTemplate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMRubricRepository : CMRepository
- (CMRubricTemplate *)insertRubric;
- (nullable CMRubricTemplate *)findById:(NSString *)rubricId error:(NSError **)error;
- (nullable CMRubricTemplate *)activeRubricForTenant:(NSError **)error;
/// Find a specific version; used when a scorecard was created against an older rubric.
- (nullable CMRubricTemplate *)findById:(NSString *)rubricId
                          rubricVersion:(int64_t)version
                                  error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
