//
//  CMAttachmentAllowlist.h
//  CourierMatch
//
//  Validates attachment MIME type against magic-number header bytes and enforces
//  per-tenant maximum file size.  See design.md §11.2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Default maximum attachment size: 10 MB.
extern NSUInteger const CMAttachmentDefaultMaxSizeBytes;

@interface CMAttachmentAllowlist : NSObject

/// Configurable ceiling in bytes.  Defaults to `CMAttachmentDefaultMaxSizeBytes`.
/// Tenants may set a lower value; values above the default are clamped.
@property (nonatomic, assign) NSUInteger maxSizeBytes;

+ (instancetype)shared;

/// Returns YES when `declaredMIME` is on the allowlist (image/jpeg, image/png,
/// application/pdf) AND the leading bytes of `data` match the expected magic
/// number for that MIME type.
/// On failure, `*error` is set to CMErrorCodeAttachmentTooLarge,
/// CMErrorCodeAttachmentMimeNotAllowed, or CMErrorCodeAttachmentMagicMismatch.
- (BOOL)validateData:(NSData *)data
        declaredMIME:(NSString *)declaredMIME
               error:(NSError **)error;

/// Returns the MIME type inferred purely from magic bytes, or nil if unknown.
- (nullable NSString *)mimeTypeFromMagicBytes:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
