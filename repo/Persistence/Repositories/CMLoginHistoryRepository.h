//
//  CMLoginHistoryRepository.h
//  CourierMatch
//

#import "CMRepository.h"
#import "CMLoginHistory.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMLoginHistoryRepository : CMRepository

- (CMLoginHistory *)recordEntryForUserId:(NSString *)userId
                                 tenantId:(NSString *)tenantId
                                  outcome:(NSString *)outcome;

- (nullable NSArray<CMLoginHistory *> *)recentForUserId:(NSString *)userId
                                                    limit:(NSUInteger)limit
                                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
