#import "CMAuditRepository.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMAuditRepository
+ (NSString *)entityName { return @"AuditEntry"; }
+ (BOOL)entitySupportsSoftDelete { return NO; } // AuditEntry is append-only, no deletedAt

- (CMAuditEntry *)insertEntry {
    CMAuditEntry *e = [NSEntityDescription insertNewObjectForEntityForName:@"AuditEntry"
                                                    inManagedObjectContext:self.context];
    e.entryId   = [[NSUUID UUID] UUIDString];
    e.createdAt = [NSDate date];
    return e;
}

- (CMAuditEntry *)latestEntryForTenant:(NSString *)tenantId error:(NSError **)error {
    NSFetchRequest *req = [self scopedFetchRequestWithPredicate:nil];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
    req.fetchLimit = 1;
    return [[self.context cm_executeFetch:req error:error] firstObject];
}

- (NSArray<CMAuditEntry *> *)entriesAfter:(NSString *)afterEntryId
                                  forTenant:(NSString *)tenantId
                                      limit:(NSUInteger)limit
                                      error:(NSError **)error {
    NSMutableArray<NSPredicate *> *preds = [NSMutableArray array];
    if (afterEntryId.length > 0) {
        // Fetch the cursor entry to get its createdAt.
        NSFetchRequest *cur = [self scopedFetchRequestWithPredicate:
                               [NSPredicate predicateWithFormat:@"entryId == %@", afterEntryId]];
        cur.fetchLimit = 1;
        CMAuditEntry *anchor = [[self.context cm_executeFetch:cur error:error] firstObject];
        if (anchor) {
            [preds addObject:[NSPredicate predicateWithFormat:@"createdAt > %@", anchor.createdAt]];
        }
    }
    NSFetchRequest *req = [self scopedFetchRequestWithPredicate:
                           preds.count ? [NSCompoundPredicate andPredicateWithSubpredicates:preds] : nil];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
    if (limit > 0) req.fetchLimit = limit;
    return [self.context cm_executeFetch:req error:error];
}
@end
