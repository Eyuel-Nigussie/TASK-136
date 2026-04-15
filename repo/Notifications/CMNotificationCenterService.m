//
//  CMNotificationCenterService.m
//  CourierMatch
//

#import "CMNotificationCenterService.h"
#import "CMNotificationItem.h"
#import "CMNotificationRepository.h"
#import "CMNotificationTemplateRenderer.h"
#import "CMNotificationRateLimiter.h"
#import "CMWorkEntities.h"
#import "CMAuditService.h"
#import "CMTenantContext.h"
#import "CMTenantRepository.h"
#import "CMTenant.h"
#import "CMCoreDataStack.h"
#import "NSManagedObjectContext+CMHelpers.h"
#import "CMDebugLogger.h"
#import "CMError.h"

// UNUserNotificationCenter import removed — in-app notification center only per spec.

static NSString * const kTag = @"notif.service";
static NSString * const kDigestTemplateKey = @"digest";

NSNotificationName const CMNotificationUnreadCountDidChangeNotification =
    @"CMNotificationUnreadCountDidChangeNotification";

@interface CMNotificationCenterService ()
@property (nonatomic, strong) CMNotificationRepository       *repository;
@property (nonatomic, strong) CMNotificationTemplateRenderer  *renderer;
@property (nonatomic, strong) CMNotificationRateLimiter       *rateLimiter;
@end

@implementation CMNotificationCenterService

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithRepository:nil renderer:nil rateLimiter:nil];
}

- (instancetype)initWithRepository:(CMNotificationRepository *)repository
                          renderer:(CMNotificationTemplateRenderer *)renderer
                       rateLimiter:(CMNotificationRateLimiter *)rateLimiter {
    if ((self = [super init])) {
        NSManagedObjectContext *ctx = [CMCoreDataStack shared].viewContext;
        _repository  = repository  ?: [[CMNotificationRepository alloc] initWithContext:ctx];
        _renderer    = renderer    ?: [CMNotificationTemplateRenderer shared];
        _rateLimiter = rateLimiter ?: [[CMNotificationRateLimiter alloc] initWithRepository:_repository];
    }
    return self;
}

#pragma mark - Emit

- (void)emitNotificationForEvent:(NSString *)templateKey
                         payload:(NSDictionary *)payload
                 recipientUserId:(NSString *)recipientUserId
               subjectEntityType:(NSString *)subjectEntityType
                 subjectEntityId:(NSString *)subjectEntityId
                      completion:(void (^)(CMNotificationItem * _Nullable, NSError * _Nullable))completion {

    CMLogInfo(kTag, @"emit begin: template=%@, recipient=%@", templateKey, [CMDebugLogger redact:recipientUserId]);

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *bgCtx) {
        NSError *error = nil;

        // ---- Repositories scoped to background context ----
        CMNotificationRepository *bgRepo =
            [[CMNotificationRepository alloc] initWithContext:bgCtx];
        CMNotificationRateLimiter *bgLimiter =
            [[CMNotificationRateLimiter alloc] initWithRepository:bgRepo];

        // ---- Resolve tenant config for template overrides ----
        NSDictionary *tenantConfigJSON = [self tenantConfigJSONInContext:bgCtx];

        // ---- Render template ----
        CMRenderedNotification *rendered =
            [self.renderer renderTemplateForKey:templateKey
                                        payload:payload
                               tenantConfigJSON:tenantConfigJSON];
        NSString *renderedTitle = rendered.title ?: templateKey;
        NSString *renderedBody  = rendered.body  ?: @"";

        // ---- Rate-limit check ----
        NSDate *now = [NSDate date];
        NSString *tenantId = [CMTenantContext shared].currentTenantId ?: @"";
        CMRateLimitDecision decision =
            [bgLimiter checkLimitForTenantId:tenantId
                                 templateKey:templateKey
                                        date:now
                                       error:&error];
        if (error) {
            CMLogError(kTag, @"rate limit check failed: %@", error);
            // Proceed with allow on error — do not drop notifications.
            decision = CMRateLimitDecisionAllow;
            error = nil;
        }

        NSString *bucketKey = [CMNotificationRateLimiter bucketKeyForTenantId:tenantId
                                                                  templateKey:templateKey
                                                                         date:now];

        // ---- Persist the individual notification ----
        CMNotificationItem *item = [bgRepo insertNotification];
        item.templateKey       = templateKey;
        item.payloadJSON       = payload;
        item.renderedTitle     = renderedTitle;
        item.renderedBody      = renderedBody;
        item.recipientUserId   = recipientUserId;
        item.subjectEntityType = subjectEntityType;
        item.subjectEntityId   = subjectEntityId;
        item.rateLimitBucket   = bucketKey;

        if (decision == CMRateLimitDecisionAllow) {
            item.status = CMNotificationStatusActive;
            CMLogInfo(kTag, @"persisted active notification id=%@", [CMDebugLogger redact:item.notificationId]);
        } else {
            item.status = CMNotificationStatusCoalesced;
            CMLogInfo(kTag, @"persisted coalesced notification id=%@ (bucket saturated)",
                      [CMDebugLogger redact:item.notificationId]);
        }

        // ---- Audit: durable audit entry for notification creation ----
        [[CMAuditService shared] recordAction:@"notification.created"
                                   targetType:@"NotificationItem"
                                     targetId:item.notificationId
                                   beforeJSON:nil
                                    afterJSON:@{@"status": item.status ?: @"",
                                                @"templateKey": item.templateKey ?: @"",
                                                @"recipientUserId": recipientUserId ?: @""}
                                       reason:@"Notification created"
                                   completion:nil];

        // ---- Digest management (only when coalesced) ----
        CMNotificationItem *digestItem = nil;
        if (decision == CMRateLimitDecisionCoalesce) {
            digestItem = [self findOrCreateDigestForTenantId:tenantId
                                                templateKey:templateKey
                                                       date:now
                                               recipientUserId:recipientUserId
                                                 repository:bgRepo
                                                    context:bgCtx
                                                      error:&error];
            if (digestItem) {
                // Append this child to the digest's childIds.
                NSMutableArray *ids = [NSMutableArray arrayWithArray:digestItem.childIds ?: @[]];
                [ids addObject:item.notificationId];
                digestItem.childIds = [ids copy];
                digestItem.updatedAt = [NSDate date];

                // Re-render the digest template with the current child count.
                NSDictionary *digestPayload = @{ @"count": @(ids.count) };
                CMRenderedNotification *digestRendered =
                    [self.renderer renderTemplateForKey:kDigestTemplateKey
                                                payload:digestPayload
                                       tenantConfigJSON:tenantConfigJSON];
                if (digestRendered) {
                    digestItem.renderedTitle = digestRendered.title;
                    digestItem.renderedBody  = digestRendered.body;
                }

                CMLogInfo(kTag, @"digest id=%@ updated with child=%@ (total children=%lu)",
                          [CMDebugLogger redact:digestItem.notificationId],
                          [CMDebugLogger redact:item.notificationId],
                          (unsigned long)ids.count);
            }
        }

        // ---- Write WorkNotificationExpiry sidecar record ----
        // This gives the purge job an authoritative expiry input.
        // Default retention: 30 days from creation.
        static NSTimeInterval const kDefaultRetentionSeconds = 30.0 * 24.0 * 60.0 * 60.0;
        CMWorkNotificationExpiry *expiry = [NSEntityDescription
            insertNewObjectForEntityForName:@"WorkNotificationExpiry"
                     inManagedObjectContext:bgCtx];
        expiry.notificationId = item.notificationId;
        expiry.tenantId = tenantId;
        expiry.expiresAt = [now dateByAddingTimeInterval:kDefaultRetentionSeconds];

        // ---- Save ----
        BOOL saved = [bgCtx cm_saveWithError:&error];
        if (!saved) {
            CMLogError(kTag, @"save failed during emit: %@", error);
            [self callCompletion:completion item:nil error:error];
            return;
        }

        // The item returned to the caller: the digest (if coalesced) or the active item.
        CMNotificationItem *resultItem = (digestItem ?: item);

        CMLogInfo(kTag, @"emit complete: resultId=%@ status=%@",
                  [CMDebugLogger redact:resultItem.notificationId], resultItem.status);

        // NOTE: System notification mirroring via UNUserNotificationCenter is
        // intentionally omitted. The spec requires an "in-app notification
        // center only (offline-safe)" design. All notifications are surfaced
        // exclusively through the in-app CMNotificationListViewController.

        // ---- Post unread count change ----
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CMNotificationUnreadCountDidChangeNotification
                              object:self];
        });

        [self callCompletion:completion item:resultItem error:nil];
    }];
}

#pragma mark - Read & Ack

- (BOOL)markRead:(NSString *)notificationId error:(NSError **)error {
    CMLogInfo(kTag, @"markRead: id=%@", [CMDebugLogger redact:notificationId]);

    CMNotificationItem *item = [self findNotificationById:notificationId error:error];
    if (!item) {
        CMLogWarn(kTag, @"markRead: notification not found id=%@", [CMDebugLogger redact:notificationId]);
        return NO;
    }

    NSDate *now = [NSDate date];
    item.readAt    = now;
    item.updatedAt = now;

    // Durable audit entry for notification read.
    [[CMAuditService shared] recordAction:@"notification.read"
                               targetType:@"NotificationItem"
                                 targetId:notificationId
                               beforeJSON:@{@"readAt": @"nil"}
                                afterJSON:@{@"readAt": [now description]}
                                   reason:@"Notification marked as read"
                               completion:nil];

    // If this is a digest, cascade readAt to all children.
    if ([item.templateKey isEqualToString:kDigestTemplateKey] && item.childIds.count > 0) {
        [self cascadeReadAtToChildren:item.childIds date:now error:error];
    }

    BOOL saved = [self.repository.context cm_saveWithError:error];
    if (saved) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CMNotificationUnreadCountDidChangeNotification
                              object:self];
        });
    }
    return saved;
}

- (BOOL)markAcknowledged:(NSString *)notificationId error:(NSError **)error {
    CMLogInfo(kTag, @"markAcknowledged: id=%@", [CMDebugLogger redact:notificationId]);

    CMNotificationItem *item = [self findNotificationById:notificationId error:error];
    if (!item) {
        CMLogWarn(kTag, @"markAcknowledged: notification not found id=%@", [CMDebugLogger redact:notificationId]);
        return NO;
    }

    NSDate *now = [NSDate date];
    item.ackedAt   = now;
    item.updatedAt = now;

    // Also mark read if not already read.
    if (!item.readAt) {
        item.readAt = now;
        [[CMAuditService shared] recordAction:@"notification.read"
                                   targetType:@"NotificationItem" targetId:notificationId
                                   beforeJSON:@{@"readAt": @"nil"}
                                    afterJSON:@{@"readAt": [now description]}
                                       reason:@"Implicit read via acknowledgement" completion:nil];
    }

    // Durable audit entry for notification acknowledgement.
    [[CMAuditService shared] recordAction:@"notification.ack"
                               targetType:@"NotificationItem"
                                 targetId:notificationId
                               beforeJSON:@{@"ackedAt": @"nil"}
                                afterJSON:@{@"ackedAt": [now description]}
                                   reason:@"Notification acknowledged"
                               completion:nil];

    // If this is a digest, cascade ackedAt (and readAt) to all children.
    if ([item.templateKey isEqualToString:kDigestTemplateKey] && item.childIds.count > 0) {
        [self cascadeAckedAtToChildren:item.childIds date:now error:error];
    }

    BOOL saved = [self.repository.context cm_saveWithError:error];
    if (saved) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:CMNotificationUnreadCountDidChangeNotification
                              object:self];
        });
    }
    return saved;
}

#pragma mark - Queries

- (NSUInteger)unreadCountForCurrentUser {
    NSString *userId = [CMTenantContext shared].currentUserId;
    if (!userId) return 0;

    NSError *error = nil;
    NSArray *items = [self.repository unreadForUser:userId limit:0 error:&error];
    if (error) {
        CMLogError(kTag, @"unreadCount fetch failed: %@", error);
        return 0;
    }
    return items.count;
}

- (NSArray<CMNotificationItem *> *)unreadNotificationsForCurrentUser:(NSUInteger)limit
                                                                error:(NSError **)error {
    NSString *userId = [CMTenantContext shared].currentUserId;
    if (!userId) {
        CMLogWarn(kTag, @"unreadNotifications: no current user");
        return @[];
    }
    return [self.repository unreadForUser:userId limit:limit error:error];
}

- (NSArray<CMNotificationItem *> *)allNotificationsForCurrentUser:(NSUInteger)limit
                                                             error:(NSError **)error {
    NSString *userId = [CMTenantContext shared].currentUserId;
    if (!userId) {
        CMLogWarn(kTag, @"allNotifications: no current user");
        return @[];
    }
    return [self.repository allForUser:userId limit:limit error:error];
}

#pragma mark - Digest Management

/// Finds an existing rolling digest for the given saturated bucket, or creates
/// a new one. A digest can span up to maxDigestMinutes. If the existing digest
/// has exceeded that window, a new digest is created.
- (CMNotificationItem *)findOrCreateDigestForTenantId:(NSString *)tenantId
                                          templateKey:(NSString *)templateKey
                                                 date:(NSDate *)date
                                      recipientUserId:(NSString *)recipientUserId
                                           repository:(CMNotificationRepository *)repo
                                              context:(NSManagedObjectContext *)ctx
                                                error:(NSError **)error {
    // Look for an existing active digest for this recipient + template category
    // that was created within the last maxDigestMinutes.
    int64_t currentMinute = [CMNotificationRateLimiter minuteBucketForDate:date];
    NSUInteger maxMinutes = [CMNotificationRateLimiter maxDigestMinutes];

    // Search window: digests created up to maxDigestMinutes ago that are still active.
    NSDate *windowStart = [NSDate dateWithTimeIntervalSince1970:(currentMinute - maxMinutes) * 60.0];

    NSPredicate *pred = [NSPredicate predicateWithFormat:
        @"templateKey == %@ AND recipientUserId == %@ AND status == %@ AND createdAt >= %@",
        kDigestTemplateKey, recipientUserId, CMNotificationStatusActive, windowStart];

    NSFetchRequest *req = [repo scopedFetchRequestWithPredicate:pred];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
    req.fetchLimit = 1;

    NSArray<CMNotificationItem *> *existing = [ctx cm_executeFetch:req error:error];

    if (existing.count > 0) {
        CMNotificationItem *existingDigest = existing.firstObject;

        // Check if the existing digest has exceeded the max window.
        int64_t digestMinute = [CMNotificationRateLimiter minuteBucketForDate:existingDigest.createdAt];
        int64_t minutesSinceCreation = currentMinute - digestMinute;

        if (minutesSinceCreation < (int64_t)maxMinutes) {
            CMLogInfo(kTag, @"reusing existing digest id=%@ (age=%lld min, max=%lu)",
                      [CMDebugLogger redact:existingDigest.notificationId], minutesSinceCreation, (unsigned long)maxMinutes);
            return existingDigest;
        }

        CMLogInfo(kTag, @"existing digest id=%@ exceeded max window (%lld min >= %lu), creating new",
                  [CMDebugLogger redact:existingDigest.notificationId], minutesSinceCreation, (unsigned long)maxMinutes);
    }

    // Create a new digest item.
    CMNotificationItem *digest = [repo insertNotification];
    digest.templateKey       = kDigestTemplateKey;
    digest.status            = CMNotificationStatusActive;
    digest.recipientUserId   = recipientUserId;
    digest.childIds          = @[];
    digest.rateLimitBucket   = [CMNotificationRateLimiter bucketKeyForTenantId:tenantId
                                                                   templateKey:kDigestTemplateKey
                                                                          date:date];

    CMLogInfo(kTag, @"created new digest id=%@ for tenant=%@, templateKey=%@",
              [CMDebugLogger redact:digest.notificationId], [CMDebugLogger redact:tenantId], templateKey);

    // Durable audit entry for digest creation.
    [[CMAuditService shared] recordAction:@"notification.created"
                               targetType:@"NotificationItem"
                                 targetId:digest.notificationId
                               beforeJSON:nil
                                afterJSON:@{@"status": @"active", @"templateKey": @"digest"}
                                   reason:@"Digest notification created"
                               completion:nil];

    return digest;
}

#pragma mark - Cascade helpers

- (void)cascadeReadAtToChildren:(NSArray *)childIds date:(NSDate *)date error:(NSError **)error {
    for (NSString *childId in childIds) {
        CMNotificationItem *child = [self findNotificationById:childId error:error];
        if (child && !child.readAt) {
            child.readAt    = date;
            child.updatedAt = date;
            [[CMAuditService shared] recordAction:@"notification.read"
                                       targetType:@"NotificationItem" targetId:childId
                                       beforeJSON:@{@"readAt": @"nil"}
                                        afterJSON:@{@"readAt": [date description]}
                                           reason:@"Cascaded read from digest" completion:nil];
        }
    }
}

- (void)cascadeAckedAtToChildren:(NSArray *)childIds date:(NSDate *)date error:(NSError **)error {
    for (NSString *childId in childIds) {
        CMNotificationItem *child = [self findNotificationById:childId error:error];
        if (child) {
            if (!child.readAt) {
                child.readAt = date;
                [[CMAuditService shared] recordAction:@"notification.read"
                                           targetType:@"NotificationItem" targetId:childId
                                           beforeJSON:@{@"readAt": @"nil"}
                                            afterJSON:@{@"readAt": [date description]}
                                               reason:@"Cascaded read from digest ack" completion:nil];
            }
            if (!child.ackedAt) {
                child.ackedAt   = date;
                child.updatedAt = date;
                [[CMAuditService shared] recordAction:@"notification.ack"
                                           targetType:@"NotificationItem" targetId:childId
                                           beforeJSON:@{@"ackedAt": @"nil"}
                                            afterJSON:@{@"ackedAt": [date description]}
                                               reason:@"Cascaded ack from digest" completion:nil];
            }
        }
    }
}

#pragma mark - Helpers

/// Recipient-auth check: notifications are scoped to the current user.
/// A user can only look up notifications addressed to them. If the notification
/// belongs to another user, nil is returned (effectively a 404), preventing
/// cross-user read/ack manipulation within the same tenant.
- (CMNotificationItem *)findNotificationById:(NSString *)notificationId error:(NSError **)error {
    NSString *currentUserId = [CMTenantContext shared].currentUserId;
    NSPredicate *pred;
    if (currentUserId.length > 0) {
        pred = [NSCompoundPredicate andPredicateWithSubpredicates:@[
            [NSPredicate predicateWithFormat:@"notificationId == %@", notificationId],
            [NSPredicate predicateWithFormat:@"recipientUserId == %@", currentUserId],
        ]];
    } else {
        pred = [NSPredicate predicateWithFormat:@"notificationId == %@", notificationId];
    }
    return (CMNotificationItem *)[self.repository fetchOneWithPredicate:pred error:error];
}

- (NSDictionary *)tenantConfigJSONInContext:(NSManagedObjectContext *)ctx {
    NSString *tenantId = [CMTenantContext shared].currentTenantId;
    if (!tenantId) return nil;

    CMTenantRepository *tenantRepo = [[CMTenantRepository alloc] initWithContext:ctx];
    NSError *err = nil;
    CMTenant *tenant = [tenantRepo findByTenantId:tenantId error:&err];
    if (err) {
        CMLogWarn(kTag, @"tenant lookup failed: %@", err);
        return nil;
    }
    return tenant.configJSON;
}

- (void)callCompletion:(void (^)(CMNotificationItem *, NSError *))completion
                  item:(CMNotificationItem *)item
                 error:(NSError *)error {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(item, error);
    });
}

@end
