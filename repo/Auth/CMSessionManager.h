//
//  CMSessionManager.h
//  CourierMatch
//
//  Session lifecycle and heartbeat per design.md §4.3 and questions.md Q11:
//    - 15-minute idle timeout with sliding window.
//    - 30-second heartbeat (foreground) + heartbeat on scene resume.
//    - Forced-logout check by comparing `forceLogoutAt` with `issuedAt`.
//    - Synchronous preflight for sensitive actions.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const CMSessionDidOpenNotification;
extern NSNotificationName const CMSessionDidExpireNotification;
extern NSNotificationName const CMSessionDidForceLogoutNotification;

extern NSTimeInterval const CMSessionIdleTimeout;   // 900 s
extern NSTimeInterval const CMSessionHeartbeat;     // 30 s
extern NSTimeInterval const CMSessionBackgroundGrace; // 30 s

@class CMUserAccount;

@interface CMSessionManager : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL hasActiveSession;
@property (nonatomic, copy, readonly, nullable) NSString *currentSessionId;
@property (nonatomic, strong, readonly, nullable) NSDate *issuedAt;
@property (nonatomic, strong, readonly, nullable) NSDate *lastActivityAt;

/// Called by CMAuthService on successful auth. Starts the heartbeat and
/// records activity.
- (void)openSessionForUser:(CMUserAccount *)user;

/// Record user activity (touches, key events). Called from the root window
/// gesture recognizer installed in SceneDelegate (wired in Step 11).
- (void)recordActivity;

/// Voluntary logout. Clears TenantContext, tears down session.
- (void)logout;

/// Called on every scene resume to immediately re-check forced logout.
- (void)handleSceneDidBecomeActive;

/// Called on scene background. Starts a 30-second grace window before tearing
/// the session down (§4.3).
- (void)handleSceneDidEnterBackground;

/// Synchronous preflight for sensitive actions (score finalize, appeal
/// decide, permission change, export, attachment upload) per Q11.
/// Returns YES iff the session is still valid AND a freshly fetched
/// `forceLogoutAt` has not invalidated it. On NO, the session is torn down
/// and `CMSessionDidForceLogoutNotification` is posted before returning.
- (BOOL)preflightSensitiveActionWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
