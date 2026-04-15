//
//  CMAttachmentHashingService.m
//  CourierMatch
//

#import "CMAttachmentHashingService.h"
#import "CMAttachment.h"
#import "CMFileLocations.h"
#import "CMError.h"
#import "CMDebugLogger.h"
#import "CMAuditService.h"
#import "CMCoreDataStack.h"
#import "NSManagedObjectContext+CMHelpers.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *const kTagHashing = @"attachment.hashing";

@interface CMAttachmentHashingService ()
@property (nonatomic, strong) NSOperationQueue *hashQueue;
@end

@implementation CMAttachmentHashingService

+ (instancetype)shared {
    static CMAttachmentHashingService *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAttachmentHashingService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _hashQueue = [[NSOperationQueue alloc] init];
        _hashQueue.name = @"com.eaglepoint.couriermatch.attachment-hashing";
        _hashQueue.qualityOfService = NSQualityOfServiceUserInitiated;
        _hashQueue.maxConcurrentOperationCount = 2;
    }
    return self;
}

#pragma mark - Public

- (void)hashFileAtURL:(NSURL *)url
           completion:(CMHashCompletion)completion {

    [self.hashQueue addOperationWithBlock:^{
        NSError *readError = nil;
        NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
        if (!data) {
            CMLogError(kTagHashing, @"cannot read file for hashing: %@", readError);
            if (completion) {
                completion(nil, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                               message:@"Cannot read file for hashing"
                                       underlyingError:readError]);
            }
            return;
        }
        NSString *hex = [self sha256HexOfData:data];
        CMLogInfo(kTagHashing, @"computed hash for %@", url.lastPathComponent);
        if (completion) {
            completion(hex, nil);
        }
    }];
}

- (void)validateAttachment:(CMAttachment *)attachment
                completion:(CMHashValidationCompletion)completion {

    // Capture identifiers and the stored hash on the calling thread so we do
    // not cross-context the managed object.
    NSString *attachmentId       = attachment.attachmentId;
    NSString *tenantId           = attachment.tenantId;
    NSString *storedHash         = attachment.sha256Hex;
    NSString *storagePathRel     = attachment.storagePathRelative;

    [self.hashQueue addOperationWithBlock:^{
        // Resolve absolute URL.
        NSURL *tenantDir = [CMFileLocations attachmentsDirectoryForTenantId:tenantId
                                                           createIfNeeded:NO];
        if (!tenantDir) {
            CMLogError(kTagHashing, @"invalid tenantId for validation: %@", tenantId);
            if (completion) {
                completion(NO, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                              message:@"Invalid tenant directory"]);
            }
            return;
        }
        NSURL *fileURL = [tenantDir URLByAppendingPathComponent:storagePathRel];

        NSError *readError = nil;
        NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&readError];
        if (!data) {
            CMLogError(kTagHashing, @"cannot read attachment for validation: %@", readError);
            if (completion) {
                completion(NO, [CMError errorWithCode:CMErrorCodeFileIOFailed
                                              message:@"Cannot read attachment file"
                                      underlyingError:readError]);
            }
            return;
        }

        NSString *recomputedHash = [self sha256HexOfData:data];
        BOOL matches = [recomputedHash isEqualToString:storedHash];

        if (!matches) {
            CMLogError(kTagHashing, @"TAMPER DETECTED for attachment %@: hash mismatch",
                       [CMDebugLogger redact:attachmentId]);

            // Update Core Data on a background context.
            [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
                NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"Attachment"];
                req.predicate = [NSPredicate predicateWithFormat:@"attachmentId == %@", attachmentId];
                req.fetchLimit = 1;
                NSError *fetchErr = nil;
                NSArray *results = [ctx cm_executeFetch:req error:&fetchErr];
                CMAttachment *bgAttachment = results.firstObject;
                if (bgAttachment) {
                    bgAttachment.hashStatus = CMAttachmentHashStatusTampered;
                    bgAttachment.updatedAt  = [NSDate date];
                    NSError *saveErr = nil;
                    [ctx cm_saveWithError:&saveErr];
                    if (saveErr) {
                        CMLogError(kTagHashing, @"failed to save tamper status: %@", saveErr);
                    }
                }
            }];

            // Fire audit entry.
            [[CMAuditService shared] recordAction:@"attachment.tamper_suspected"
                                       targetType:@"Attachment"
                                         targetId:attachmentId
                                       beforeJSON:@{@"sha256Hex": storedHash ?: @"(nil)"}
                                        afterJSON:@{@"sha256Hex": recomputedHash}
                                           reason:@"SHA-256 mismatch on read-back validation"
                                       completion:nil];

            if (completion) {
                completion(NO, [CMError errorWithCode:CMErrorCodeAttachmentHashMismatch
                                              message:@"Attachment hash mismatch — tamper suspected"]);
            }
        } else {
            CMLogInfo(kTagHashing, @"validation passed for attachment %@", [CMDebugLogger redact:attachmentId]);
            if (completion) {
                completion(YES, nil);
            }
        }
    }];
}

- (void)cancelAll {
    [self.hashQueue cancelAllOperations];
}

#pragma mark - Private

- (NSString *)sha256HexOfData:(NSData *)data {
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return [hex copy];
}

@end
