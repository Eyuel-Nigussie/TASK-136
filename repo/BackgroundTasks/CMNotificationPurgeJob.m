//
//  CMNotificationPurgeJob.m
//  CourierMatch
//

#import "CMNotificationPurgeJob.h"
#import "CMCoreDataStack.h"
#import "CMWorkEntities.h"
#import "CMNotificationItem.h"
#import "CMTenantRepository.h"
#import "CMTenant.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSString * const kLogTag = @"NotifPurge";
static NSUInteger const kBatchSize = 100;
/// Notifications older than this are eligible for archival (30 days).
static NSTimeInterval const kRetentionInterval = 30.0 * 24.0 * 60.0 * 60.0;

@implementation CMNotificationPurgeJob

- (void)runPurgeWithProtectedDataAvailable:(BOOL)protectedDataAvailable
                               expiredFlag:(BOOL *)expiredFlag
                                completion:(void (^)(NSUInteger, NSError *))completion {
    if (!completion) return;

    if (![CMCoreDataStack shared].isLoaded) {
        CMLogWarn(kLogTag, @"Core Data not loaded, aborting purge");
        completion(0, nil);
        return;
    }

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSDate *now = [NSDate date];
        // Retention cutoff: only archive notifications older than 30 days.
        NSDate *retentionCutoff = [now dateByAddingTimeInterval:-kRetentionInterval];
        NSUInteger totalPurged = 0;
        NSError *error = nil;

        // ── Phase 1: Delete expired rows from Work sidecar ──────────────
        // CMWorkNotificationExpiry is on the Work store which uses
        // NSFileProtectionCompleteUntilFirstUserAuthentication, so it is
        // always accessible once the user has unlocked after reboot.

        totalPurged = [self purgeExpiredWorkNotificationsInContext:ctx
                                                          before:now
                                                     expiredFlag:expiredFlag
                                                           error:&error];
        if (error) {
            CMLogError(kLogTag, @"Phase 1 (work sidecar purge) failed: %@", error);
            completion(totalPurged, error);
            return;
        }

        CMLogInfo(kLogTag, @"Phase 1: purged %lu expired work notification rows",
                  (unsigned long)totalPurged);

        // ── Phase 2: Archive main-store notifications if protected data available ──
        if (protectedDataAvailable) {
            if (expiredFlag && *expiredFlag) {
                CMLogInfo(kLogTag, @"Skipping Phase 2: task expired");
                completion(totalPurged, nil);
                return;
            }

            NSUInteger archived = [self archiveExpiredMainNotificationsInContext:ctx
                                                                         before:retentionCutoff
                                                                    expiredFlag:expiredFlag
                                                                          error:&error];
            if (error) {
                CMLogError(kLogTag, @"Phase 2 (main store archive) failed: %@", error);
                // Non-fatal: we already purged the sidecar successfully.
                completion(totalPurged, nil);
                return;
            }

            CMLogInfo(kLogTag, @"Phase 2: archived %lu main-store notifications",
                      (unsigned long)archived);
        } else {
            CMLogInfo(kLogTag, @"Phase 2 skipped: protected data unavailable (Q7)");
        }

        completion(totalPurged, nil);
    }];
}

// ── Phase 1: Purge expired CMWorkNotificationExpiry rows ────────────────────

- (NSUInteger)purgeExpiredWorkNotificationsInContext:(NSManagedObjectContext *)ctx
                                             before:(NSDate *)cutoff
                                        expiredFlag:(BOOL *)expiredFlag
                                              error:(NSError **)outError {
    NSUInteger totalDeleted = 0;

    while (YES) {
        // Cooperatively yield if the task expiration handler has fired.
        if (expiredFlag && *expiredFlag) {
            CMLogInfo(kLogTag, @"Work purge: cooperative exit after %lu deletions",
                      (unsigned long)totalDeleted);
            break;
        }

        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"WorkNotificationExpiry"];
        req.predicate = [NSPredicate predicateWithFormat:@"expiresAt < %@", cutoff];
        req.fetchLimit = kBatchSize;

        NSError *fetchError = nil;
        NSArray<CMWorkNotificationExpiry *> *batch = [ctx cm_executeFetch:req error:&fetchError];
        if (fetchError) {
            if (outError) *outError = fetchError;
            return totalDeleted;
        }

        if (batch.count == 0) {
            break; // No more expired rows.
        }

        for (CMWorkNotificationExpiry *expiry in batch) {
            [ctx deleteObject:expiry];
        }

        NSError *saveError = nil;
        if (![ctx cm_saveWithError:&saveError]) {
            CMLogError(kLogTag, @"Work purge: save failed after deleting batch: %@", saveError);
            if (outError) *outError = saveError;
            return totalDeleted;
        }

        totalDeleted += batch.count;

        // If we got fewer than the batch size, there are no more rows.
        if (batch.count < kBatchSize) {
            break;
        }
    }

    return totalDeleted;
}

// ── Phase 2: Archive expired / acked notifications in main store ────────────

- (NSUInteger)archiveExpiredMainNotificationsInContext:(NSManagedObjectContext *)ctx
                                               before:(NSDate *)cutoff
                                          expiredFlag:(BOOL *)expiredFlag
                                                error:(NSError **)outError {
    NSUInteger totalArchived = 0;

    while (YES) {
        if (expiredFlag && *expiredFlag) {
            CMLogInfo(kLogTag, @"Main archive: cooperative exit after %lu archives",
                      (unsigned long)totalArchived);
            break;
        }

        // Find notification items that are either:
        //   - acked (ackedAt != nil) AND older than retention cutoff, or
        //   - read and older than retention cutoff
        // AND not yet soft-deleted.
        // Tenant scoping: process all tenants; tenantId is on each row.
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"NotificationItem"];
        req.predicate = [NSPredicate predicateWithFormat:
            @"deletedAt == nil AND createdAt < %@ AND (ackedAt != nil OR readAt != nil)", cutoff];
        req.fetchLimit = kBatchSize;

        NSError *fetchError = nil;
        NSArray<CMNotificationItem *> *batch = [ctx cm_executeFetch:req error:&fetchError];
        if (fetchError) {
            if (outError) *outError = fetchError;
            return totalArchived;
        }

        if (batch.count == 0) {
            break;
        }

        NSDate *now = [NSDate date];
        for (CMNotificationItem *item in batch) {
            // Soft-delete: set deletedAt to mark as archived.
            item.deletedAt = now;
            item.updatedAt = now;
        }

        NSError *saveError = nil;
        if (![ctx cm_saveWithError:&saveError]) {
            CMLogError(kLogTag, @"Main archive: save failed after archiving batch: %@", saveError);
            if (outError) *outError = saveError;
            return totalArchived;
        }

        totalArchived += batch.count;

        if (batch.count < kBatchSize) {
            break;
        }
    }

    return totalArchived;
}

@end
