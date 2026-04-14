//
//  CMAttachmentService.h
//  CourierMatch
//
//  Main attachment service — save, load, delete, and thumbnail generation.
//  Coordinates validation (CMAttachmentAllowlist), hashing
//  (CMAttachmentHashingService), and persistence (CMAttachmentRepository).
//
//  See design.md §11.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class CMAttachment;

NS_ASSUME_NONNULL_BEGIN

/// Completion block for save operations.
typedef void (^CMAttachmentSaveCompletion)(CMAttachment * _Nullable attachment,
                                           NSError      * _Nullable error);

/// Completion block for thumbnail generation.
typedef void (^CMThumbnailCompletion)(UIImage * _Nullable thumbnail,
                                      NSError * _Nullable error);

@interface CMAttachmentService : NSObject

+ (instancetype)shared;

/// Validate, write to the sandbox, persist a CMAttachment record with
/// `hashStatus = pending`, and enqueue asynchronous SHA-256 computation.
///
/// @param filename   Original filename (used as display name, not for storage path).
/// @param data       Raw file bytes.
/// @param mimeType   Declared MIME type (must match magic bytes).
/// @param ownerType  Owning entity type (e.g. "Order", "Appeal").
/// @param ownerId    Owning entity identifier.
/// @param completion Called on an arbitrary queue.
- (void)saveAttachmentWithFilename:(NSString *)filename
                              data:(NSData *)data
                          mimeType:(NSString *)mimeType
                         ownerType:(NSString *)ownerType
                           ownerId:(NSString *)ownerId
                        completion:(CMAttachmentSaveCompletion)completion;

/// Synchronously load the raw bytes for an attachment.  If the attachment has
/// `hashStatus = ready`, the hash is re-validated off-main (tamper detection).
///
/// @param attachment  The managed object to load.
/// @param error       Set on file-I/O failure.
/// @return Raw file data, or nil on error.
- (nullable NSData *)loadAttachment:(CMAttachment *)attachment
                              error:(NSError **)error;

/// Delete both the on-disk file and the Core Data record.
///
/// @param attachment  The managed object to remove.
/// @param error       Set on failure.
/// @return YES on success.
- (BOOL)deleteAttachment:(CMAttachment *)attachment
                   error:(NSError **)error;

/// Generate (or return cached) thumbnail for an image attachment.
/// PDFs receive a first-page render.  Result is delivered on an arbitrary queue.
///
/// @param attachment  The managed object.
/// @param completion  Delivers the thumbnail UIImage or an error.
- (void)generateThumbnail:(CMAttachment *)attachment
               completion:(CMThumbnailCompletion)completion;

/// Flush the in-memory thumbnail cache.  Called automatically on
/// `CMMemoryPressureNotification`.
- (void)flushThumbnailCache;

@end

NS_ASSUME_NONNULL_END
