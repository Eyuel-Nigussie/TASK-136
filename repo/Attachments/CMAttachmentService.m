//
//  CMAttachmentService.m
//  CourierMatch
//

#import "CMAttachmentService.h"
#import "CMAttachment.h"
#import "CMAttachmentAllowlist.h"
#import "CMAttachmentHashingService.h"
#import "CMAttachmentRepository.h"
#import "CMFileLocations.h"
#import "CMFileProtection.h"
#import "CMTenantContext.h"
#import "CMSessionManager.h"
#import "CMCoreDataStack.h"
#import "CMAuditService.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"
#import "AppDelegate.h"

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

static NSString *const kTagService = @"attachment.service";

/// Thumbnail longest-edge size in points.
static CGFloat const kThumbnailMaxEdge = 200.0;

/// 30-day expiry interval.
static NSTimeInterval const kExpiryInterval = 30.0 * 24.0 * 60.0 * 60.0;

@interface CMAttachmentService ()
@property (nonatomic, strong) NSCache *thumbnailCache;
@property (nonatomic, strong) dispatch_queue_t thumbnailQueue;
@end

@implementation CMAttachmentService

+ (instancetype)shared {
    static CMAttachmentService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAttachmentService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _thumbnailCache = [[NSCache alloc] init];
        _thumbnailCache.name = @"com.eaglepoint.couriermatch.thumb-cache";
        _thumbnailCache.countLimit = 100;

        _thumbnailQueue = dispatch_queue_create(
            "com.eaglepoint.couriermatch.thumbnail-gen",
            DISPATCH_QUEUE_CONCURRENT);

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(handleMemoryPressure:)
                   name:CMMemoryPressureNotification
                 object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Save

- (void)saveAttachmentWithFilename:(NSString *)filename
                              data:(NSData *)data
                          mimeType:(NSString *)mimeType
                         ownerType:(NSString *)ownerType
                           ownerId:(NSString *)ownerId
                        completion:(CMAttachmentSaveCompletion)completion {

    // 0. Session preflight: ensure session is active and not expired/revoked.
    NSError *preflightErr = nil;
    if (![[CMSessionManager shared] preflightSensitiveActionWithError:&preflightErr]) {
        CMLogWarn(@"attachment.service", @"Attachment upload blocked by session preflight: %@", preflightErr);
        if (completion) { completion(nil, preflightErr); }
        return;
    }

    // 1. Validate MIME + magic + size.
    NSError *valError = nil;
    if (![[CMAttachmentAllowlist shared] validateData:data
                                        declaredMIME:mimeType
                                               error:&valError]) {
        // Audit the rejection.
        [[CMAuditService shared] recordAction:@"attachment.reject"
                                   targetType:@"Attachment"
                                     targetId:nil
                                   beforeJSON:nil
                                    afterJSON:@{
                                        @"filename": filename ?: @"",
                                        @"mimeType": mimeType ?: @"",
                                        @"sizeBytes": @(data.length),
                                        @"reason": valError.localizedDescription ?: @""
                                    }
                                       reason:valError.localizedDescription
                                   completion:nil];
        if (completion) { completion(nil, valError); }
        return;
    }

    // 2. Resolve tenant directory.
    NSString *tenantId = [CMTenantContext shared].currentTenantId;
    if (!tenantId.length) {
        NSError *err = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                      message:@"No tenant context for attachment save"];
        if (completion) { completion(nil, err); }
        return;
    }

    NSURL *tenantDir = [CMFileLocations attachmentsDirectoryForTenantId:tenantId
                                                       createIfNeeded:YES];
    if (!tenantDir) {
        NSError *err = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                      message:@"Cannot create tenant attachment directory"];
        if (completion) { completion(nil, err); }
        return;
    }

    // 3. Build storage path: {UUID}.{ext}
    NSString *extension = [self extensionForMIME:mimeType] ?: @"bin";
    NSString *storageFilename = [NSString stringWithFormat:@"%@.%@",
                                 [[NSUUID UUID] UUIDString], extension];
    NSURL *fileURL = [tenantDir URLByAppendingPathComponent:storageFilename];

    // 4. Write to disk.
    NSError *writeError = nil;
    if (![data writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) {
        CMLogError(kTagService, @"file write failed: %@", writeError);
        NSError *err = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                      message:@"Failed to write attachment file"
                              underlyingError:writeError];
        if (completion) { completion(nil, err); }
        return;
    }

    // 5. Apply file protection.
    NSError *protError = nil;
    if (![CMFileProtection apply:CMProtectionClassCompleteUnlessOpen
                           toURL:fileURL
                           error:&protError]) {
        CMLogWarn(kTagService, @"file protection apply failed: %@", protError);
        // Non-fatal: the file is written, but protection may be weaker.
    }

    // 6. Persist Core Data record.
    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        CMAttachmentRepository *repo = [[CMAttachmentRepository alloc] initWithContext:ctx];
        CMAttachment *att = [repo insertAttachment];

        NSDate *now = [NSDate date];
        att.filename            = filename;
        att.mimeType            = mimeType.lowercaseString;
        att.sizeBytes           = (int64_t)data.length;
        att.ownerType           = ownerType;
        att.ownerId             = ownerId;
        att.storagePathRelative = storageFilename;
        att.capturedAt          = now;
        att.expiresAt           = [NSDate dateWithTimeInterval:kExpiryInterval sinceDate:now];
        att.capturedByUserId    = [CMTenantContext shared].currentUserId ?: @"";
        att.hashStatus          = CMAttachmentHashStatusPending;
        att.sha256Hex           = nil;

        NSError *saveErr = nil;
        if (![ctx cm_saveWithError:&saveErr]) {
            CMLogError(kTagService, @"Core Data save failed for attachment: %@", saveErr);
            // Clean up the written file.
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
            if (completion) {
                completion(nil, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                               message:@"Failed to save attachment record"
                                       underlyingError:saveErr]);
            }
            return;
        }

        // Capture values needed after async hash.
        NSString *attachmentId = att.attachmentId;

        CMLogInfo(kTagService, @"saved attachment %@ (%@, %lld bytes)",
                  attachmentId, mimeType, (long long)data.length);

        // 7. Enqueue async hash.
        [[CMAttachmentHashingService shared] hashFileAtURL:fileURL
                                                completion:^(NSString *hexHash, NSError *hashErr) {
            if (hashErr) {
                CMLogError(kTagService, @"hashing failed for %@: %@", attachmentId, hashErr);
                return;
            }
            // Update the record with the computed hash.
            [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *hashCtx) {
                NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Attachment"];
                req.predicate = [NSPredicate predicateWithFormat:@"attachmentId == %@", attachmentId];
                req.fetchLimit = 1;
                NSError *fetchErr = nil;
                NSArray *results = [hashCtx cm_executeFetch:req error:&fetchErr];
                CMAttachment *toUpdate = results.firstObject;
                if (toUpdate) {
                    toUpdate.sha256Hex  = hexHash;
                    toUpdate.hashStatus = CMAttachmentHashStatusReady;
                    toUpdate.updatedAt  = [NSDate date];
                    NSError *sErr = nil;
                    if (![hashCtx cm_saveWithError:&sErr]) {
                        CMLogError(kTagService, @"failed to save hash for %@: %@",
                                   attachmentId, sErr);
                    } else {
                        CMLogInfo(kTagService, @"hash ready for attachment %@", attachmentId);
                    }
                }
            }];
        }];

        if (completion) {
            completion(att, nil);
        }
    }];
}

#pragma mark - Load

- (nullable NSData *)loadAttachment:(CMAttachment *)attachment
                              error:(NSError **)error {
    NSURL *fileURL = [self absoluteURLForAttachment:attachment];
    if (!fileURL) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                    message:@"Cannot resolve attachment file path"];
        }
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readError];
    if (!data) {
        CMLogError(kTagService, @"load failed for %@: %@", attachment.attachmentId, readError);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                    message:@"Cannot read attachment file"
                            underlyingError:readError];
        }
        return nil;
    }

    // If hash is ready, kick off a background re-validation (tamper detection).
    if ([attachment.hashStatus isEqualToString:CMAttachmentHashStatusReady]) {
        [[CMAttachmentHashingService shared] validateAttachment:attachment
                                                    completion:^(BOOL valid, NSError *valErr) {
            if (!valid) {
                CMLogError(kTagService, @"tamper detected on load for %@",
                           attachment.attachmentId);
                // The hashing service already updates hashStatus + fires audit.
            }
        }];
    }

    return data;
}

#pragma mark - Delete

- (BOOL)deleteAttachment:(CMAttachment *)attachment
                   error:(NSError **)error {
    // Remove file.
    NSURL *fileURL = [self absoluteURLForAttachment:attachment];
    if (fileURL) {
        NSError *rmErr = nil;
        if (![[NSFileManager defaultManager] removeItemAtURL:fileURL error:&rmErr]) {
            CMLogWarn(kTagService, @"file removal failed for %@: %@",
                      attachment.attachmentId, rmErr);
            // Continue to delete the record even if the file is already gone.
        }
    }

    // Remove cached thumbnail.
    [self.thumbnailCache removeObjectForKey:attachment.attachmentId];
    NSURL *thumbURL = [self thumbnailURLForAttachmentId:attachment.attachmentId];
    if (thumbURL) {
        [[NSFileManager defaultManager] removeItemAtURL:thumbURL error:NULL];
    }

    // Delete Core Data record.
    NSManagedObjectContext *ctx = attachment.managedObjectContext;
    [ctx deleteObject:attachment];
    NSError *saveErr = nil;
    if (![ctx cm_saveWithError:&saveErr]) {
        CMLogError(kTagService, @"failed to delete attachment record: %@", saveErr);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeFileIOFailed
                                    message:@"Failed to delete attachment record"
                            underlyingError:saveErr];
        }
        return NO;
    }

    CMLogInfo(kTagService, @"deleted attachment %@", attachment.attachmentId);
    return YES;
}

#pragma mark - Thumbnails

- (void)generateThumbnail:(CMAttachment *)attachment
               completion:(CMThumbnailCompletion)completion {
    NSString *attachmentId = attachment.attachmentId;

    // Check memory cache first.
    UIImage *cached = [self.thumbnailCache objectForKey:attachmentId];
    if (cached) {
        if (completion) { completion(cached, nil); }
        return;
    }

    // Check disk cache.
    NSURL *thumbDiskURL = [self thumbnailURLForAttachmentId:attachmentId];
    if (thumbDiskURL && [[NSFileManager defaultManager] fileExistsAtPath:thumbDiskURL.path]) {
        dispatch_async(self.thumbnailQueue, ^{
            UIImage *diskImage = [UIImage imageWithContentsOfFile:thumbDiskURL.path];
            if (diskImage) {
                [self.thumbnailCache setObject:diskImage forKey:attachmentId];
                if (completion) { completion(diskImage, nil); }
                return;
            }
            // Disk cache corrupt — fall through to regeneration below.
            [self regenerateThumbnailForAttachment:attachment completion:completion];
        });
        return;
    }

    // Generate new thumbnail off-main.
    [self regenerateThumbnailForAttachment:attachment completion:completion];
}

- (void)flushThumbnailCache {
    [self.thumbnailCache removeAllObjects];
    CMLogInfo(kTagService, @"thumbnail memory cache flushed");
}

#pragma mark - Memory Pressure

- (void)handleMemoryPressure:(NSNotification *)note {
    [self flushThumbnailCache];
}

#pragma mark - Private Helpers

- (nullable NSURL *)absoluteURLForAttachment:(CMAttachment *)attachment {
    NSURL *tenantDir = [CMFileLocations attachmentsDirectoryForTenantId:attachment.tenantId
                                                       createIfNeeded:NO];
    if (!tenantDir) { return nil; }
    return [tenantDir URLByAppendingPathComponent:attachment.storagePathRelative];
}

- (nullable NSURL *)thumbnailURLForAttachmentId:(NSString *)attachmentId {
    NSURL *thumbDir = [CMFileLocations thumbnailCacheDirectoryCreatingIfNeeded:YES];
    if (!thumbDir || !attachmentId) { return nil; }
    NSString *thumbFilename = [attachmentId stringByAppendingString:@"_thumb.jpg"];
    return [thumbDir URLByAppendingPathComponent:thumbFilename];
}

- (nullable NSString *)extensionForMIME:(NSString *)mime {
    NSString *lower = mime.lowercaseString;
    if ([lower isEqualToString:@"image/jpeg"])       return @"jpg";
    if ([lower isEqualToString:@"image/png"])        return @"png";
    if ([lower isEqualToString:@"application/pdf"])  return @"pdf";
    return nil;
}

- (void)regenerateThumbnailForAttachment:(CMAttachment *)attachment
                              completion:(CMThumbnailCompletion)completion {
    NSString *attachmentId = attachment.attachmentId;
    NSString *mimeType     = attachment.mimeType;
    NSURL *fileURL         = [self absoluteURLForAttachment:attachment];

    dispatch_async(self.thumbnailQueue, ^{
        if (!fileURL) {
            if (completion) {
                completion(nil, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                               message:@"Cannot resolve file for thumbnail"]);
            }
            return;
        }

        NSError *readErr = nil;
        NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readErr];
        if (!data) {
            if (completion) {
                completion(nil, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                               message:@"Cannot read file for thumbnail"
                                       underlyingError:readErr]);
            }
            return;
        }

        UIImage *thumb = nil;

        if ([mimeType isEqualToString:@"image/jpeg"] ||
            [mimeType isEqualToString:@"image/png"]) {
            thumb = [self thumbnailFromImageData:data];
        } else if ([mimeType isEqualToString:@"application/pdf"]) {
            thumb = [self thumbnailFromPDFData:data];
        }

        if (!thumb) {
            if (completion) {
                completion(nil, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                               message:@"Thumbnail generation failed"]);
            }
            return;
        }

        // Cache in memory.
        [self.thumbnailCache setObject:thumb forKey:attachmentId];

        // Persist to disk cache.
        NSURL *thumbDiskURL = [self thumbnailURLForAttachmentId:attachmentId];
        if (thumbDiskURL) {
            NSData *jpegData = UIImageJPEGRepresentation(thumb, 0.7);
            [jpegData writeToURL:thumbDiskURL atomically:YES];
        }

        if (completion) { completion(thumb, nil); }
    });
}

- (nullable UIImage *)thumbnailFromImageData:(NSData *)data {
    UIImage *full = [UIImage imageWithData:data];
    if (!full) { return nil; }

    CGSize targetSize = [self scaledSizeForSize:full.size maxEdge:kThumbnailMaxEdge];
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    [full drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumb;
}

- (nullable UIImage *)thumbnailFromPDFData:(NSData *)data {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    if (!provider) { return nil; }

    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (!pdf) { return nil; }

    CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
    if (!page) {
        CGPDFDocumentRelease(pdf);
        return nil;
    }

    CGRect mediaBox = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    CGSize targetSize = [self scaledSizeForSize:mediaBox.size maxEdge:kThumbnailMaxEdge];

    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (ctx) {
        // White background.
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, targetSize.width, targetSize.height));

        // PDF pages are flipped.
        CGContextTranslateCTM(ctx, 0, targetSize.height);
        CGContextScaleCTM(ctx, targetSize.width / mediaBox.size.width,
                          -targetSize.height / mediaBox.size.height);
        CGContextDrawPDFPage(ctx, page);
    }
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGPDFDocumentRelease(pdf);
    return thumb;
}

- (CGSize)scaledSizeForSize:(CGSize)original maxEdge:(CGFloat)maxEdge {
    if (original.width <= 0 || original.height <= 0) {
        return CGSizeMake(maxEdge, maxEdge);
    }
    CGFloat longestEdge = MAX(original.width, original.height);
    if (longestEdge <= maxEdge) { return original; }
    CGFloat scale = maxEdge / longestEdge;
    return CGSizeMake(floor(original.width * scale),
                      floor(original.height * scale));
}

@end
