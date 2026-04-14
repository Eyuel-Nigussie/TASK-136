//
//  CMAttachmentHashingService.h
//  CourierMatch
//
//  NSOperationQueue-backed SHA-256 hasher.  Every hash computation is routed
//  through this service (questions.md Q13).  Quality of service is
//  `userInitiated`, max concurrent ops = 2.
//
//  See design.md §11.3.
//

#import <Foundation/Foundation.h>

@class CMAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for hash computation.  `hexHash` is the lowercase hex-encoded
/// SHA-256 digest, or nil on error.
typedef void (^CMHashCompletion)(NSString * _Nullable hexHash,
                                 NSError  * _Nullable error);

/// Completion block for validation.  `valid` is YES when the on-disk hash
/// matches the stored sha256Hex.
typedef void (^CMHashValidationCompletion)(BOOL valid,
                                           NSError * _Nullable error);

@interface CMAttachmentHashingService : NSObject

+ (instancetype)shared;

/// Compute the SHA-256 hex digest for the file at `url`. The work is performed
/// on an internal NSOperationQueue (off-main).
- (void)hashFileAtURL:(NSURL *)url
           completion:(CMHashCompletion)completion;

/// Re-read the attachment file, recompute the hash, and compare it with the
/// stored `sha256Hex`.  Updates `hashStatus` in Core Data and fires an
/// `attachment.tamper_suspected` audit entry on mismatch.
///
/// @param attachment  The managed object.  Must have a valid `storagePathRelative`
///                    and `tenantId`.
/// @param completion  Called on an arbitrary queue with the validation result.
- (void)validateAttachment:(CMAttachment *)attachment
                completion:(CMHashValidationCompletion)completion;

/// Cancels all queued (but not yet running) hash operations.
- (void)cancelAll;

@end

NS_ASSUME_NONNULL_END
