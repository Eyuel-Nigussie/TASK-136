//
//  CMSessionManager.m
//  CourierMatch
//

#import "CMSessionManager.h"
#import "CMUserAccount.h"
#import "CMUserRepository.h"
#import "CMTenantContext.h"
#import "CMCoreDataStack.h"
#import "CMError.h"
#import "CMDebugLogger.h"

NSNotificationName const CMSessionDidOpenNotification        = @"CMSessionDidOpenNotification";
NSNotificationName const CMSessionDidExpireNotification      = @"CMSessionDidExpireNotification";
NSNotificationName const CMSessionDidForceLogoutNotification = @"CMSessionDidForceLogoutNotification";

NSTimeInterval const CMSessionIdleTimeout     = 15 * 60.0;
NSTimeInterval const CMSessionHeartbeat       = 30.0;
NSTimeInterval const CMSessionBackgroundGrace = 30.0;

@interface CMSessionManager ()
@property (nonatomic, copy,   readwrite, nullable) NSString *currentSessionId;
@property (nonatomic, strong, readwrite, nullable) NSDate *issuedAt;
@property (nonatomic, strong, readwrite, nullable) NSDate *lastActivityAt;

@property (nonatomic, copy) NSString *currentUserId;
@property (nonatomic, strong, nullable) dispatch_source_t heartbeat;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong, nullable) NSDate *backgroundedAt;
@end

@implementation CMSessionManager

+ (instancetype)shared {
    static CMSessionManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMSessionManager new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("com.eaglepoint.couriermatch.session", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)hasActiveSession {
    return self.currentSessionId != nil;
}

#pragma mark - Lifecycle

- (void)openSessionForUser:(CMUserAccount *)user {
    self.currentSessionId = [[NSUUID UUID] UUIDString];
    self.currentUserId    = user.userId;
    NSDate *now = [NSDate date];
    self.issuedAt         = now;
    self.lastActivityAt   = now;
    self.backgroundedAt   = nil;
    [self startHeartbeat];
    CMLogInfo(@"session", @"opened session %@ for user %@",
              [CMDebugLogger redact:self.currentSessionId],
              [CMDebugLogger redact:user.userId]);
    [[NSNotificationCenter defaultCenter] postNotificationName:CMSessionDidOpenNotification
                                                        object:self];
}

- (void)logout {
    [self teardownWithReason:@"logout"
                 notification:nil];
}

- (void)teardownWithReason:(NSString *)reason
              notification:(nullable NSNotificationName)name {
    if (!self.currentSessionId) { return; }
    CMLogInfo(@"session", @"teardown (%@) for session %@", reason,
              [CMDebugLogger redact:self.currentSessionId]);
    self.currentSessionId = nil;
    self.currentUserId    = nil;
    self.issuedAt         = nil;
    self.lastActivityAt   = nil;
    self.backgroundedAt   = nil;
    [self stopHeartbeat];
    [[CMTenantContext shared] clear];
    if (name) {
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:self];
    }
}

#pragma mark - Activity

- (void)recordActivity {
    if (!self.currentSessionId) { return; }
    self.lastActivityAt = [NSDate date];
}

#pragma mark - Scene transitions

- (void)handleSceneDidBecomeActive {
    // Foreground grace check: if we backgrounded and came back within the
    // grace window, do nothing. Otherwise evaluate idle + forced logout.
    if (self.backgroundedAt) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.backgroundedAt];
        self.backgroundedAt = nil;
        if (elapsed > CMSessionBackgroundGrace) {
            [self evaluateSession];
            return;
        }
    }
    [self evaluateSession];
}

- (void)handleSceneDidEnterBackground {
    self.backgroundedAt = [NSDate date];
}

#pragma mark - Heartbeat

- (void)startHeartbeat {
    [self stopHeartbeat];
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    uint64_t interval = (uint64_t)(CMSessionHeartbeat * NSEC_PER_SEC);
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, interval),
                              interval,
                              (uint64_t)(1 * NSEC_PER_SEC));
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timer, ^{
        [weakSelf evaluateSession];
    });
    dispatch_resume(timer);
    self.heartbeat = timer;
}

- (void)stopHeartbeat {
    if (self.heartbeat) {
        dispatch_source_cancel(self.heartbeat);
        self.heartbeat = nil;
    }
}

#pragma mark - Evaluation

- (void)evaluateSession {
    if (!self.currentSessionId) { return; }

    // Idle timeout.
    NSDate *last = self.lastActivityAt ?: self.issuedAt;
    if (last && [[NSDate date] timeIntervalSinceDate:last] >= CMSessionIdleTimeout) {
        [self teardownWithReason:@"idle-expiry"
                     notification:CMSessionDidExpireNotification];
        return;
    }

    // Forced logout check (Q11).
    if (self.currentUserId && ![self forcedLogoutGateIsOK]) {
        [self teardownWithReason:@"force-logout"
                     notification:CMSessionDidForceLogoutNotification];
        return;
    }
}

- (BOOL)forcedLogoutGateIsOK {
    __block BOOL ok = YES;
    NSString *uid = self.currentUserId;
    NSDate *iss = self.issuedAt;
    if (!uid || !iss) { return NO; }

    // Use a private child context so we don't hop onto the main thread from
    // the heartbeat queue.
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc]
                                   initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    ctx.persistentStoreCoordinator = [CMCoreDataStack shared].container.persistentStoreCoordinator;
    [ctx performBlockAndWait:^{
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"UserAccount"];
        req.predicate = [NSPredicate predicateWithFormat:@"userId == %@", uid];
        req.fetchLimit = 1;
        CMUserAccount *u = [[ctx executeFetchRequest:req error:NULL] firstObject];
        if (!u) { ok = NO; return; }
        if ([u.status isEqualToString:CMUserStatusDisabled] ||
            [u.status isEqualToString:CMUserStatusDeleted]) {
            ok = NO; return;
        }
        if (u.forceLogoutAt && [u.forceLogoutAt timeIntervalSinceDate:iss] > 0) {
            ok = NO; return;
        }
    }];
    return ok;
}

#pragma mark - Preflight

- (BOOL)preflightSensitiveActionWithError:(NSError **)error {
    if (!self.currentSessionId) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAuthSessionExpired
                                    message:@"No active session"];
        }
        return NO;
    }

    NSDate *last = self.lastActivityAt ?: self.issuedAt;
    if (last && [[NSDate date] timeIntervalSinceDate:last] >= CMSessionIdleTimeout) {
        [self teardownWithReason:@"idle-expiry-preflight"
                     notification:CMSessionDidExpireNotification];
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAuthSessionExpired
                                    message:@"Session has expired"];
        }
        return NO;
    }

    if (![self forcedLogoutGateIsOK]) {
        [self teardownWithReason:@"force-logout-preflight"
                     notification:CMSessionDidForceLogoutNotification];
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAuthForcedLogout
                                    message:@"Session was revoked by an administrator"];
        }
        return NO;
    }
    return YES;
}

@end
