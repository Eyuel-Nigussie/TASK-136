#import "CMAuditRepository.h"
#import "CMError.h"
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
    // Guard: reject empty tenantId to prevent cross-tenant chain corruption.
    if (!tenantId || tenantId.length == 0) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeTenantScopingViolation
                                    message:@"tenantId is required for audit chain lookup"];
        }
        return nil;
    }

    // Use explicit tenantId predicate — do NOT rely on CMTenantContext ambient state.
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
    req.predicate = [NSPredicate predicateWithFormat:@"tenantId == %@", tenantId];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
    req.fetchLimit = 1;
    return [[self.context cm_executeFetch:req error:error] firstObject];
}

- (NSArray<CMAuditEntry *> *)entriesAfter:(NSString *)afterEntryId
                                  forTenant:(NSString *)tenantId
                                      limit:(NSUInteger)limit
                                      error:(NSError **)error {
    // Guard: reject empty tenantId.
    if (!tenantId || tenantId.length == 0) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeTenantScopingViolation
                                    message:@"tenantId is required for audit chain query"];
        }
        return nil;
    }

    // Always filter by explicit tenantId.
    NSMutableArray<NSPredicate *> *preds = [NSMutableArray array];
    [preds addObject:[NSPredicate predicateWithFormat:@"tenantId == %@", tenantId]];

    if (afterEntryId.length > 0) {
        // Fetch the cursor entry (also tenant-scoped) to get its createdAt.
        NSFetchRequest *cur = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
        cur.predicate = [NSPredicate predicateWithFormat:
                         @"tenantId == %@ AND entryId == %@", tenantId, afterEntryId];
        cur.fetchLimit = 1;
        CMAuditEntry *anchor = [[self.context cm_executeFetch:cur error:error] firstObject];
        if (anchor) {
            [preds addObject:[NSPredicate predicateWithFormat:@"createdAt > %@", anchor.createdAt]];
        }
    }

    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AuditEntry"];
    req.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:preds];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
    if (limit > 0) req.fetchLimit = limit;
    return [self.context cm_executeFetch:req error:error];
}
@end
