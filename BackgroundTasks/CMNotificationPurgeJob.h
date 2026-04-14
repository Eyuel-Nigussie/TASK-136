//
//  CMNotificationPurgeJob.h
//  CourierMatch
//
//  Purges expired and acknowledged notifications from the Work sidecar
//  (CMWorkNotificationExpiry) and optionally archives corresponding entries
//  in the main Core Data store if protected data is available (Q7).
//
//  Called by CMBackgroundTaskManager during the notifications.purge
//  BGProcessingTask.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMNotificationPurgeJob : NSObject

/// Runs the purge operation.
///
/// 1. Deletes CMWorkNotificationExpiry rows where expiresAt < now from the
///    Work sidecar (always accessible in background).
/// 2. If protectedDataAvailable is YES, soft-deletes (sets deletedAt) the
///    matching CMNotificationItem rows in the main store whose ackedAt is
///    non-nil or whose expiresAt has passed.
///
/// The caller passes a pointer to a BOOL flag that the BGTask expiration
/// handler sets to YES; the job checks it between batches and exits
/// cooperatively if expired.
///
/// @param protectedDataAvailable Whether the main Core Data store can be
///        opened (Q7: NSFileProtectionComplete requires device unlocked).
/// @param expiredFlag Pointer to a BOOL set to YES by the task expiration
///        handler. The job stops iteration when *expiredFlag becomes YES.
/// @param completion Called when the purge finishes. `purged` is the total
///        number of Work sidecar rows deleted. `error` is non-nil on failure.
- (void)runPurgeWithProtectedDataAvailable:(BOOL)protectedDataAvailable
                               expiredFlag:(BOOL *)expiredFlag
                                completion:(void (^)(NSUInteger purged, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
