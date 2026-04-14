//
//  CMAttachmentCleanupJob.h
//  CourierMatch
//
//  Deletes expired attachments (30-day window from capturedAt) and removes
//  orphaned thumbnail cache entries.  Designed to be invoked by a
//  BGProcessingTask (Step 10) or called on-demand.
//
//  See design.md §11.4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Completion block for cleanup.
/// @param deletedCount  Number of expired attachments removed.
/// @param error         Non-nil if the cleanup could not complete.
typedef void (^CMCleanupCompletion)(NSUInteger deletedCount,
                                    NSError * _Nullable error);

@interface CMAttachmentCleanupJob : NSObject

+ (instancetype)shared;

/// Run the full cleanup pass:
///   1. Fetch attachments whose `expiresAt < now`, in batches of 50.
///   2. Delete the on-disk file for each.
///   3. Delete the Core Data record.
///   4. Scan the thumbnail cache directory and remove any thumbnails whose
///      attachment record no longer exists.
///
/// @param completion Called on an arbitrary queue.
- (void)runCleanup:(nullable CMCleanupCompletion)completion;

@end

NS_ASSUME_NONNULL_END
