//
//  CMFileLocations.m
//  CourierMatch
//

#import "CMFileLocations.h"

@implementation CMFileLocations

+ (NSURL *)urlForSearchPath:(NSSearchPathDirectory)dir
                  subfolder:(NSString *)sub
                     create:(BOOL)create {
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:dir
                                                         inDomains:NSUserDomainMask].firstObject;
    NSURL *url = sub.length ? [base URLByAppendingPathComponent:sub isDirectory:YES] : base;
    if (create) {
        [[NSFileManager defaultManager] createDirectoryAtURL:url
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:NULL];
    }
    return url;
}

+ (NSURL *)appSupportDirectoryCreatingIfNeeded:(BOOL)create {
    return [self urlForSearchPath:NSApplicationSupportDirectory
                        subfolder:@"CourierMatch"
                           create:create];
}

+ (NSURL *)mainStoreURL {
    NSURL *dir = [self appSupportDirectoryCreatingIfNeeded:YES];
    return [dir URLByAppendingPathComponent:@"CourierMatch.sqlite" isDirectory:NO];
}

+ (NSURL *)sidecarStoreURL {
    NSURL *dir = [self appSupportDirectoryCreatingIfNeeded:YES];
    return [dir URLByAppendingPathComponent:@"work.sqlite" isDirectory:NO];
}

+ (NSString *)sanitizedPathComponent:(NSString *)input {
    if (!input || input.length == 0) { return nil; }
    // Strip everything except alphanumeric characters and hyphens to prevent path traversal.
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
    NSMutableString *safe = [NSMutableString string];
    for (NSUInteger i = 0; i < input.length; i++) {
        unichar c = [input characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [safe appendFormat:@"%C", c];
        }
    }
    return safe.length > 0 ? [safe copy] : nil;
}

+ (NSURL *)attachmentsDirectoryForTenantId:(NSString *)tenantId
                            createIfNeeded:(BOOL)create {
    NSString *safeTenant = [self sanitizedPathComponent:tenantId];
    if (!safeTenant) { return nil; }
    NSString *sub = [@"attachments" stringByAppendingPathComponent:safeTenant];
    return [self urlForSearchPath:NSDocumentDirectory subfolder:sub create:create];
}

+ (NSURL *)thumbnailCacheDirectoryCreatingIfNeeded:(BOOL)create {
    return [self urlForSearchPath:NSCachesDirectory
                        subfolder:@"attachment-thumbs"
                           create:create];
}

+ (NSURL *)debugLogDirectoryCreatingIfNeeded:(BOOL)create {
    return [self urlForSearchPath:NSCachesDirectory
                        subfolder:@"debug-log"
                           create:create];
}

@end
