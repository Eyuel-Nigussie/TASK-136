//
//  CMBackgroundTaskManager.h
//  CourierMatch
//
//  Registers and handles all four BGTaskScheduler tasks at launch.
//  See design.md section 12, Q5, Q7.
//
//  Tasks:
//    com.eaglepoint.couriermatch.match.refresh        — BGAppRefreshTask
//    com.eaglepoint.couriermatch.attachments.cleanup   — BGProcessingTask
//    com.eaglepoint.couriermatch.notifications.purge   — BGProcessingTask
//    com.eaglepoint.couriermatch.audit.verify          — BGProcessingTask
//
//  Each handler checks isProtectedDataAvailable before touching the main
//  Core Data store, yields on thermal/battery stress (Q5), cooperatively
//  handles expiration, and reschedules itself.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Task identifiers. Must match Info.plist BGTaskSchedulerPermittedIdentifiers.
extern NSString * const CMBGTaskMatchRefresh;
extern NSString * const CMBGTaskAttachmentsCleanup;
extern NSString * const CMBGTaskNotificationsPurge;
extern NSString * const CMBGTaskAuditVerify;

@interface CMBackgroundTaskManager : NSObject

+ (instancetype)shared;

/// Call once in application:didFinishLaunchingWithOptions: BEFORE the end
/// of that method. Registers all four task handlers with BGTaskScheduler.
- (void)registerAllTasks;

/// Schedules all four tasks. Safe to call multiple times; uses
/// BGTaskScheduler submitTaskRequest:error: which replaces existing requests
/// for the same identifier.
- (void)scheduleAllTasks;

/// Schedule individual tasks (exposed for testing / rescheduling).
- (void)scheduleMatchRefresh;
- (void)scheduleAttachmentsCleanup;
- (void)scheduleNotificationsPurge;
- (void)scheduleAuditVerify;

@end

NS_ASSUME_NONNULL_END
