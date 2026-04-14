#import "CMRepository.h"
#import "CMAuditEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAuditRepository : CMRepository
- (CMAuditEntry *)insertEntry;
/// Latest entry for the given tenant, ordered by createdAt DESC.
- (nullable CMAuditEntry *)latestEntryForTenant:(NSString *)tenantId error:(NSError **)error;
/// Entries after a given entryId for chain verification, chronological order.
- (nullable NSArray<CMAuditEntry *> *)entriesAfter:(nullable NSString *)afterEntryId
                                           forTenant:(NSString *)tenantId
                                               limit:(NSUInteger)limit
                                               error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
