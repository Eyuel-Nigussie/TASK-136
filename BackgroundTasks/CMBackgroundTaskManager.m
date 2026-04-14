//
//  CMBackgroundTaskManager.m
//  CourierMatch
//

#import "CMBackgroundTaskManager.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UIKit/UIKit.h>

#import "CMCoreDataStack.h"
#import "CMMatchEngine.h"
#import "CMItineraryRepository.h"
#import "CMItinerary.h"
#import "CMTenantContext.h"
#import "CMAuditVerifier.h"
#import "CMNotificationPurgeJob.h"
#import "CMAttachmentCleanupJob.h"
#import "CMWorkEntities.h"
#import "CMDebugLogger.h"
#import "CMErrorCodes.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSString * const kLogTag = @"BGTask";

// ── Task identifiers ────────────────────────────────────────────────────────
NSString * const CMBGTaskMatchRefresh       = @"com.eaglepoint.couriermatch.match.refresh";
NSString * const CMBGTaskAttachmentsCleanup = @"com.eaglepoint.couriermatch.attachments.cleanup";
NSString * const CMBGTaskNotificationsPurge = @"com.eaglepoint.couriermatch.notifications.purge";
NSString * const CMBGTaskAuditVerify        = @"com.eaglepoint.couriermatch.audit.verify";

// ── Scheduling intervals ────────────────────────────────────────────────────
static NSTimeInterval const kMatchRefreshInterval       = 15 * 60;   // 15 min
static NSTimeInterval const kAttachmentCleanupInterval  = 6 * 3600;  // 6 hours
static NSTimeInterval const kNotificationPurgeInterval  = 4 * 3600;  // 4 hours
static NSTimeInterval const kAuditVerifyInterval        = 12 * 3600; // 12 hours

@implementation CMBackgroundTaskManager

+ (instancetype)shared {
    static CMBackgroundTaskManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[CMBackgroundTaskManager alloc] init]; });
    return instance;
}

// ── Registration ────────────────────────────────────────────────────────────

- (void)registerAllTasks {
    BGTaskScheduler *scheduler = [BGTaskScheduler sharedScheduler];

    __weak typeof(self) weakSelf = self;

    [scheduler registerForTaskWithIdentifier:CMBGTaskMatchRefresh
                                  usingQueue:nil
                               launchHandler:^(BGTask * _Nonnull task) {
        [weakSelf handleMatchRefresh:(BGAppRefreshTask *)task];
    }];

    [scheduler registerForTaskWithIdentifier:CMBGTaskAttachmentsCleanup
                                  usingQueue:nil
                               launchHandler:^(BGTask * _Nonnull task) {
        [weakSelf handleAttachmentsCleanup:(BGProcessingTask *)task];
    }];

    [scheduler registerForTaskWithIdentifier:CMBGTaskNotificationsPurge
                                  usingQueue:nil
                               launchHandler:^(BGTask * _Nonnull task) {
        [weakSelf handleNotificationsPurge:(BGProcessingTask *)task];
    }];

    [scheduler registerForTaskWithIdentifier:CMBGTaskAuditVerify
                                  usingQueue:nil
                               launchHandler:^(BGTask * _Nonnull task) {
        [weakSelf handleAuditVerify:(BGProcessingTask *)task];
    }];

    CMLogInfo(kLogTag, @"Registered all four BGTaskScheduler tasks");
}

// ── Scheduling ──────────────────────────────────────────────────────────────

- (void)scheduleAllTasks {
    [self scheduleMatchRefresh];
    [self scheduleAttachmentsCleanup];
    [self scheduleNotificationsPurge];
    [self scheduleAuditVerify];
}

- (void)scheduleMatchRefresh {
    BGAppRefreshTaskRequest *request =
        [[BGAppRefreshTaskRequest alloc] initWithIdentifier:CMBGTaskMatchRefresh];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:kMatchRefreshInterval];

    NSError *error = nil;
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error]) {
        CMLogWarn(kLogTag, @"Failed to schedule match refresh: %@", error);
    } else {
        CMLogInfo(kLogTag, @"Scheduled match refresh in %.0f seconds", kMatchRefreshInterval);
    }
}

- (void)scheduleAttachmentsCleanup {
    BGProcessingTaskRequest *request =
        [[BGProcessingTaskRequest alloc] initWithIdentifier:CMBGTaskAttachmentsCleanup];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:kAttachmentCleanupInterval];
    request.requiresExternalPower = YES;
    request.requiresNetworkConnectivity = NO;

    NSError *error = nil;
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error]) {
        CMLogWarn(kLogTag, @"Failed to schedule attachments cleanup: %@", error);
    } else {
        CMLogInfo(kLogTag, @"Scheduled attachments cleanup in %.0f seconds", kAttachmentCleanupInterval);
    }
}

- (void)scheduleNotificationsPurge {
    BGProcessingTaskRequest *request =
        [[BGProcessingTaskRequest alloc] initWithIdentifier:CMBGTaskNotificationsPurge];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:kNotificationPurgeInterval];
    request.requiresExternalPower = YES;
    request.requiresNetworkConnectivity = NO;

    NSError *error = nil;
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error]) {
        CMLogWarn(kLogTag, @"Failed to schedule notifications purge: %@", error);
    } else {
        CMLogInfo(kLogTag, @"Scheduled notifications purge in %.0f seconds", kNotificationPurgeInterval);
    }
}

- (void)scheduleAuditVerify {
    BGProcessingTaskRequest *request =
        [[BGProcessingTaskRequest alloc] initWithIdentifier:CMBGTaskAuditVerify];
    request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:kAuditVerifyInterval];
    request.requiresExternalPower = YES;
    request.requiresNetworkConnectivity = NO;

    NSError *error = nil;
    if (![[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error]) {
        CMLogWarn(kLogTag, @"Failed to schedule audit verify: %@", error);
    } else {
        CMLogInfo(kLogTag, @"Scheduled audit verify in %.0f seconds", kAuditVerifyInterval);
    }
}

// ── Thermal / Battery Check (Q5) ───────────────────────────────────────────

/// Returns YES when the device is under thermal or battery stress and heavy
/// work should be deferred.
- (BOOL)shouldYieldForSystemConstraints {
    NSProcessInfo *pi = [NSProcessInfo processInfo];
    if (pi.thermalState >= NSProcessInfoThermalStateSerious) {
        CMLogWarn(kLogTag, @"Yielding: thermal state >= serious (%ld)", (long)pi.thermalState);
        return YES;
    }
    if (pi.isLowPowerModeEnabled) {
        CMLogWarn(kLogTag, @"Yielding: low power mode enabled");
        return YES;
    }
    return NO;
}

/// Returns YES if the main Core Data store (NSFileProtectionComplete) is
/// accessible. When the device is locked after a reboot and the user has
/// not yet authenticated, protected data is unavailable (Q7).
- (BOOL)isProtectedDataAvailable {
    __block BOOL available = NO;
    if ([NSThread isMainThread]) {
        available = [UIApplication sharedApplication].isProtectedDataAvailable;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            available = [UIApplication sharedApplication].isProtectedDataAvailable;
        });
    }
    return available;
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Match Refresh Handler (BGAppRefreshTask)
// ══════════════════════════════════════════════════════════════════════════════

- (void)handleMatchRefresh:(BGAppRefreshTask *)task {
    CMLogInfo(kLogTag, @"Match refresh task started");

    // Always reschedule for next run.
    [self scheduleMatchRefresh];

    // Q5: yield on thermal/battery stress.
    if ([self shouldYieldForSystemConstraints]) {
        CMLogInfo(kLogTag, @"Match refresh yielding due to system constraints");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    // Q7: protected data check — main store uses NSFileProtectionComplete.
    if (![self isProtectedDataAvailable]) {
        CMLogWarn(kLogTag, @"Match refresh: protected data unavailable, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    // Ensure Core Data is loaded before using it.
    if (![CMCoreDataStack shared].isLoaded) {
        CMLogWarn(kLogTag, @"Match refresh: Core Data not loaded, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    __block BOOL expired = NO;

    // Set up expiration handler: mark expired so iteration stops cooperatively.
    task.expirationHandler = ^{
        CMLogWarn(kLogTag, @"Match refresh: expiration handler fired");
        expired = YES;
    };

    // Perform on a background context.
    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSError *fetchError = nil;
        CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:ctx];
        NSArray<CMItinerary *> *itineraries = [repo activeItineraries:&fetchError];

        if (fetchError || !itineraries) {
            CMLogError(kLogTag, @"Match refresh: failed to fetch active itineraries: %@", fetchError);
            [task setTaskCompletedWithSuccess:NO];
            return;
        }

        CMLogInfo(kLogTag, @"Match refresh: processing %lu active itineraries",
                  (unsigned long)itineraries.count);

        dispatch_group_t group = dispatch_group_create();
        __block BOOL anyFailure = NO;

        for (CMItinerary *itinerary in itineraries) {
            // Cooperatively yield if the system asked us to stop.
            if (expired) {
                CMLogInfo(kLogTag, @"Match refresh: expired, stopping iteration");
                break;
            }

            // Re-check thermal/battery before each itinerary (Q5).
            if ([self shouldYieldForSystemConstraints]) {
                CMLogInfo(kLogTag, @"Match refresh: yielding mid-iteration due to system constraints");
                break;
            }

            dispatch_group_enter(group);
            [[CMMatchEngine shared] recomputeCandidatesForItinerary:itinerary
                                                         completion:^(NSError *error) {
                if (error) {
                    // CMErrorCodeMatchCandidateTruncated is non-fatal.
                    if (error.code != CMErrorCodeMatchCandidateTruncated) {
                        CMLogError(kLogTag, @"Match refresh: recompute failed for %@: %@",
                                   itinerary.itineraryId, error);
                        anyFailure = YES;
                    }
                }
                dispatch_group_leave(group);
            }];

            // Wait for this itinerary before starting the next to avoid
            // overwhelming the system. Timeout after 30 seconds per itinerary.
            dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
        }

        CMLogInfo(kLogTag, @"Match refresh: completed (expired=%d, failures=%d)",
                  expired, anyFailure);
        [task setTaskCompletedWithSuccess:!anyFailure];
    }];
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Attachments Cleanup Handler (BGProcessingTask)
// ══════════════════════════════════════════════════════════════════════════════

- (void)handleAttachmentsCleanup:(BGProcessingTask *)task {
    CMLogInfo(kLogTag, @"Attachments cleanup task started");

    // Always reschedule for next run.
    [self scheduleAttachmentsCleanup];

    // Q5: yield on thermal/battery stress.
    if ([self shouldYieldForSystemConstraints]) {
        CMLogInfo(kLogTag, @"Attachments cleanup yielding due to system constraints");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    // Q7: Check protected data for main store access.
    // The cleanup job touches files with NSFileProtectionCompleteUnlessOpen
    // and the Work sidecar. We check protected data availability because
    // the job may also need to verify hashes against the main store.
    if (![self isProtectedDataAvailable]) {
        CMLogWarn(kLogTag, @"Attachments cleanup: protected data unavailable, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    if (![CMCoreDataStack shared].isLoaded) {
        CMLogWarn(kLogTag, @"Attachments cleanup: Core Data not loaded, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    __block BOOL expired = NO;

    task.expirationHandler = ^{
        CMLogWarn(kLogTag, @"Attachments cleanup: expiration handler fired");
        expired = YES;
    };

    // Direct, compile-time-typed call to CMAttachmentCleanupJob.
    // The actual API is -runCleanup: (not -runCleanupWithCompletion:).
    // Using a direct import + typed call ensures the compiler catches any
    // signature mismatch at build time rather than failing silently at runtime.
    CMAttachmentCleanupJob *cleanupJob = [CMAttachmentCleanupJob shared];
    [cleanupJob runCleanup:^(NSUInteger deleted, NSError *err) {
        if (err) {
            CMLogError(kLogTag, @"Attachments cleanup: error: %@", err);
            [task setTaskCompletedWithSuccess:NO];
        } else {
            CMLogInfo(kLogTag, @"Attachments cleanup: deleted %lu expired attachments",
                      (unsigned long)deleted);
            [task setTaskCompletedWithSuccess:YES];
        }
    }];
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Notifications Purge Handler (BGProcessingTask)
// ══════════════════════════════════════════════════════════════════════════════

- (void)handleNotificationsPurge:(BGProcessingTask *)task {
    CMLogInfo(kLogTag, @"Notifications purge task started");

    // Always reschedule for next run.
    [self scheduleNotificationsPurge];

    // Q5: yield on thermal/battery stress.
    if ([self shouldYieldForSystemConstraints]) {
        CMLogInfo(kLogTag, @"Notifications purge yielding due to system constraints");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    if (![CMCoreDataStack shared].isLoaded) {
        CMLogWarn(kLogTag, @"Notifications purge: Core Data not loaded, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    __block BOOL expired = NO;

    task.expirationHandler = ^{
        CMLogWarn(kLogTag, @"Notifications purge: expiration handler fired");
        expired = YES;
    };

    BOOL protectedDataAvailable = [self isProtectedDataAvailable];

    CMNotificationPurgeJob *purgeJob = [[CMNotificationPurgeJob alloc] init];
    [purgeJob runPurgeWithProtectedDataAvailable:protectedDataAvailable
                                     expiredFlag:&expired
                                      completion:^(NSUInteger purged, NSError *error) {
        if (error) {
            CMLogError(kLogTag, @"Notifications purge: error: %@", error);
            [task setTaskCompletedWithSuccess:NO];
        } else {
            CMLogInfo(kLogTag, @"Notifications purge: purged %lu notifications",
                      (unsigned long)purged);
            [task setTaskCompletedWithSuccess:YES];
        }
    }];
}

// ══════════════════════════════════════════════════════════════════════════════
#pragma mark - Audit Verify Handler (BGProcessingTask)
// ══════════════════════════════════════════════════════════════════════════════

- (void)handleAuditVerify:(BGProcessingTask *)task {
    CMLogInfo(kLogTag, @"Audit verify task started");

    // Always reschedule for next run.
    [self scheduleAuditVerify];

    // Q5: yield on thermal/battery stress.
    if ([self shouldYieldForSystemConstraints]) {
        CMLogInfo(kLogTag, @"Audit verify yielding due to system constraints");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    // Q7: The audit verifier touches both the main store (for AuditEntry) and
    // the work sidecar (for WorkAuditCursor). Main store needs protected data.
    if (![self isProtectedDataAvailable]) {
        CMLogWarn(kLogTag, @"Audit verify: protected data unavailable, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    if (![CMCoreDataStack shared].isLoaded) {
        CMLogWarn(kLogTag, @"Audit verify: Core Data not loaded, rescheduling");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    __block BOOL expired = NO;

    task.expirationHandler = ^{
        CMLogWarn(kLogTag, @"Audit verify: expiration handler fired");
        expired = YES;
    };

    // Get the current tenant. If no tenant is authenticated, there is nothing
    // to verify. The audit verifier is tenant-scoped.
    NSString *tenantId = [CMTenantContext shared].currentTenantId;
    if (!tenantId.length) {
        CMLogInfo(kLogTag, @"Audit verify: no current tenant, skipping");
        [task setTaskCompletedWithSuccess:YES];
        return;
    }

    [[CMAuditVerifier shared] verifyChainForTenant:tenantId
                                          progress:^(NSUInteger verified, NSUInteger total) {
        // Check cooperative expiration during progress callbacks.
        if (expired) {
            CMLogInfo(kLogTag, @"Audit verify: expired at %lu/%lu entries",
                      (unsigned long)verified, (unsigned long)total);
            // The verifier persists its cursor, so partial progress is saved.
        }
    }
                                        completion:^(BOOL success, NSString *brokenEntryId, NSError *error) {
        if (error && !success) {
            CMLogError(kLogTag, @"Audit verify: chain verification failed: %@", error);
            [task setTaskCompletedWithSuccess:NO];
        } else {
            CMLogInfo(kLogTag, @"Audit verify: completed successfully");
            [task setTaskCompletedWithSuccess:YES];
        }
    }];
}

@end
