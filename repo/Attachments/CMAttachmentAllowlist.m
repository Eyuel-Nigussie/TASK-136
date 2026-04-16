//
//  CMAttachmentAllowlist.m
//  CourierMatch
//

#import "CMAttachmentAllowlist.h"
#import "CMError.h"
#import "CMDebugLogger.h"

NSUInteger const CMAttachmentDefaultMaxSizeBytes = 10 * 1024 * 1024; // 10 MB

static NSString *const kTagAllowlist = @"attachment.allowlist";

@implementation CMAttachmentAllowlist

+ (instancetype)shared {
    static CMAttachmentAllowlist *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAttachmentAllowlist alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _maxSizeBytes = CMAttachmentDefaultMaxSizeBytes;
        _allowedMIMETypes = [[self class] defaultAllowedMIMETypes];
    }
    return self;
}

- (void)setMaxSizeBytes:(NSUInteger)maxSizeBytes {
    // Tenants may only lower the cap, never exceed the built-in default.
    _maxSizeBytes = MIN(maxSizeBytes, CMAttachmentDefaultMaxSizeBytes);
}

- (void)setAllowedMIMETypes:(NSSet<NSString *> *)allowedMIMETypes {
    if (allowedMIMETypes.count == 0) {
        // Empty/nil reverts to default.
        _allowedMIMETypes = [[self class] defaultAllowedMIMETypes];
        return;
    }
    // Accept the tenant-admin-configured MIME set as-is. Defaults are the
    // initial value; admins can narrow OR expand via tenant config. All
    // updates are audited through CMAdminDashboardViewController.
    _allowedMIMETypes = [allowedMIMETypes copy];
}

+ (NSSet<NSString *> *)defaultAllowedMIMETypes {
    static NSSet *defaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaults = [NSSet setWithArray:@[
            @"image/jpeg",
            @"image/png",
            @"application/pdf",
        ]];
    });
    return defaults;
}

#pragma mark - Public

- (BOOL)validateData:(NSData *)data
        declaredMIME:(NSString *)declaredMIME
               error:(NSError **)error {

    // 1. Size check.
    if (data.length > self.maxSizeBytes) {
        NSString *msg = [NSString stringWithFormat:
            @"Attachment size %lu exceeds maximum %lu bytes",
            (unsigned long)data.length, (unsigned long)self.maxSizeBytes];
        CMLogWarn(kTagAllowlist, @"%@", msg);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAttachmentTooLarge message:msg];
        }
        return NO;
    }

    // 2. Declared MIME on allowlist?
    NSString *normalizedMIME = declaredMIME.lowercaseString;
    if (![self isAllowedMIME:normalizedMIME]) {
        NSString *msg = [NSString stringWithFormat:
            @"MIME type '%@' is not on the allowlist", declaredMIME];
        CMLogWarn(kTagAllowlist, @"%@", msg);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAttachmentMimeNotAllowed message:msg];
        }
        return NO;
    }

    // 3. Magic-byte sniff.
    NSString *detectedMIME = [self mimeTypeFromMagicBytes:data];
    if (!detectedMIME || ![detectedMIME isEqualToString:normalizedMIME]) {
        NSString *msg = [NSString stringWithFormat:
            @"Magic-byte mismatch: declared '%@', detected '%@'",
            declaredMIME, detectedMIME ?: @"(unknown)"];
        CMLogWarn(kTagAllowlist, @"%@", msg);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeAttachmentMagicMismatch message:msg];
        }
        return NO;
    }

    return YES;
}

- (nullable NSString *)mimeTypeFromMagicBytes:(NSData *)data {
    if (data.length < 4) { return nil; }

    const uint8_t *bytes = (const uint8_t *)data.bytes;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return @"image/jpeg";
    }

    // PNG: 89 50 4E 47 (i.e. 0x89 'P' 'N' 'G')
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return @"image/png";
    }

    // PDF: %PDF (25 50 44 46)
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        return @"application/pdf";
    }

    return nil;
}

#pragma mark - Private

- (BOOL)isAllowedMIME:(NSString *)mime {
    return [self.allowedMIMETypes containsObject:mime];
}

@end
