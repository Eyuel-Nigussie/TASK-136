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

+ (BOOL)isUUIDString:(NSString *)s {
    return [[NSUUID alloc] initWithUUIDString:s] != nil;
}

+ (NSURL *)attachmentsDirectoryForTenantId:(NSString *)tenantId
                            createIfNeeded:(BOOL)create {
    if (![self isUUIDString:tenantId]) { return nil; }
    NSString *sub = [@"attachments" stringByAppendingPathComponent:tenantId];
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
