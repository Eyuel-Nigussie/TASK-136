//
//  CMAttachmentCleanupJob.m
//  CourierMatch
//

#import "CMAttachmentCleanupJob.h"
#import "CMAttachment.h"
#import "CMAttachmentRepository.h"
#import "CMFileLocations.h"
#import "CMCoreDataStack.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSString *const kTagCleanup = @"attachment.cleanup";

/// Batch size per Core Data fetch.
static NSUInteger const kCleanupBatchSize = 50;

@implementation CMAttachmentCleanupJob

+ (instancetype)shared {
    static CMAttachmentCleanupJob *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAttachmentCleanupJob alloc] init];
    });
    return instance;
}

#pragma mark - Public

- (void)runCleanup:(CMCleanupCompletion)completion {
    CMLogInfo(kTagCleanup, @"starting cleanup pass");

    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        NSUInteger totalDeleted = 0;
        NSDate *now = [NSDate date];
        NSError *error = nil;

        // 1. Delete expired attachments in batches.
        while (YES) {
            NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Attachment"];
            req.predicate = [NSPredicate predicateWithFormat:@"expiresAt < %@", now];
            req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"expiresAt"
                                                                 ascending:YES]];
            req.fetchLimit = kCleanupBatchSize;

            NSError *fetchErr = nil;
            NSArray<CMAttachment *> *expired = [ctx cm_executeFetch:req error:&fetchErr];
            if (fetchErr) {
                CMLogError(kTagCleanup, @"fetch failed: %@", fetchErr);
                error = fetchErr;
                break;
            }
            if (expired.count == 0) { break; }

            for (CMAttachment *att in expired) {
                // Remove file from disk.
                NSURL *fileURL = [self absoluteURLForAttachment:att];
                if (fileURL) {
                    NSError *rmErr = nil;
                    if (![[NSFileManager defaultManager] removeItemAtURL:fileURL error:&rmErr]) {
                        CMLogWarn(kTagCleanup, @"file remove failed for %@: %@",
                                  att.attachmentId, rmErr);
                        // Continue — file may already be gone.
                    }
                }

                // Remove thumbnail from disk cache.
                NSURL *thumbURL = [self thumbnailURLForAttachmentId:att.attachmentId];
                if (thumbURL) {
                    [[NSFileManager defaultManager] removeItemAtURL:thumbURL error:NULL];
                }

                // Delete Core Data record.
                [ctx deleteObject:att];
                totalDeleted++;
            }

            // Save after each batch.
            NSError *saveErr = nil;
            if (![ctx cm_saveWithError:&saveErr]) {
                CMLogError(kTagCleanup, @"batch save failed: %@", saveErr);
                error = saveErr;
                break;
            }
        }

        // 2. Remove orphaned thumbnails.
        NSUInteger orphansRemoved = [self removeOrphanedThumbnailsWithContext:ctx];

        CMLogInfo(kTagCleanup, @"cleanup complete: %lu expired deleted, %lu orphan thumbs removed",
                  (unsigned long)totalDeleted, (unsigned long)orphansRemoved);

        if (completion) {
            completion(totalDeleted, error);
        }
    }];
}

#pragma mark - Private

- (nullable NSURL *)absoluteURLForAttachment:(CMAttachment *)att {
    NSURL *tenantDir = [CMFileLocations attachmentsDirectoryForTenantId:att.tenantId
                                                       createIfNeeded:NO];
    if (!tenantDir) { return nil; }
    return [tenantDir URLByAppendingPathComponent:att.storagePathRelative];
}

- (nullable NSURL *)thumbnailURLForAttachmentId:(NSString *)attachmentId {
    NSURL *thumbDir = [CMFileLocations thumbnailCacheDirectoryCreatingIfNeeded:NO];
    if (!thumbDir || !attachmentId) { return nil; }
    NSString *thumbFilename = [attachmentId stringByAppendingString:@"_thumb.jpg"];
    return [thumbDir URLByAppendingPathComponent:thumbFilename];
}

- (NSUInteger)removeOrphanedThumbnailsWithContext:(NSManagedObjectContext *)ctx {
    NSURL *thumbDir = [CMFileLocations thumbnailCacheDirectoryCreatingIfNeeded:NO];
    if (!thumbDir) { return 0; }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *enumErr = nil;
    NSArray<NSURL *> *thumbFiles =
        [fm contentsOfDirectoryAtURL:thumbDir
          includingPropertiesForKeys:nil
                             options:NSDirectoryEnumerationSkipsHiddenFiles
                               error:&enumErr];
    if (enumErr) {
        CMLogWarn(kTagCleanup, @"cannot enumerate thumbs dir: %@", enumErr);
        return 0;
    }

    NSUInteger removed = 0;
    for (NSURL *thumbURL in thumbFiles) {
        NSString *filename = thumbURL.lastPathComponent;
        // Our thumbnails are named "{attachmentId}_thumb.jpg".
        if (![filename hasSuffix:@"_thumb.jpg"]) { continue; }

        NSString *attachmentId = [filename stringByReplacingOccurrencesOfString:@"_thumb.jpg"
                                                                    withString:@""];
        if (!attachmentId.length) { continue; }

        // Check whether the attachment still exists.
        NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Attachment"];
        req.predicate = [NSPredicate predicateWithFormat:@"attachmentId == %@", attachmentId];
        req.fetchLimit = 1;
        // Use countForFetchRequest for efficiency.
        NSError *countErr = nil;
        NSUInteger count = [ctx countForFetchRequest:req error:&countErr];
        if (count == 0 || count == NSNotFound) {
            NSError *rmErr = nil;
            if ([fm removeItemAtURL:thumbURL error:&rmErr]) {
                removed++;
            } else {
                CMLogWarn(kTagCleanup, @"cannot remove orphan thumb: %@", rmErr);
            }
        }
    }

    return removed;
}

@end
