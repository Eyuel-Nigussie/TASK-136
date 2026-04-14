//
//  NSManagedObjectContext+CMHelpers.m
//  CourierMatch
//

#import "NSManagedObjectContext+CMHelpers.h"
#import "CMError.h"
#import "CMDebugLogger.h"

@implementation NSManagedObjectContext (CMHelpers)

- (BOOL)cm_saveWithError:(NSError **)error {
    if (!self.hasChanges) { return YES; }
    NSError *err = nil;
    BOOL ok = [self save:&err];
    if (!ok) {
        CMLogError(@"coredata", @"save failed: %@", err);
        if (error) {
            CMErrorCode code = CMErrorCodeCoreDataSaveFailed;
            if ([err.domain isEqualToString:NSCocoaErrorDomain] &&
                (err.code == NSManagedObjectMergeError ||
                 err.code == NSPersistentStoreSaveConflictsError)) {
                code = CMErrorCodeOptimisticLockConflict;
            } else if ([err.domain isEqualToString:NSCocoaErrorDomain] &&
                       err.code == NSValidationRelationshipLacksMinimumCountError) {
                code = CMErrorCodeValidationFailed;
            } else if ([err.domain isEqualToString:NSCocoaErrorDomain] &&
                       err.code == NSManagedObjectConstraintMergeError) {
                code = CMErrorCodeUniqueConstraintViolated;
            }
            *error = [CMError errorWithCode:code
                                    message:@"Core Data save failed"
                            underlyingError:err];
        }
    }
    return ok;
}

- (NSArray *)cm_executeFetch:(NSFetchRequest *)request error:(NSError **)error {
    NSError *err = nil;
    NSArray *out = [self executeFetchRequest:request error:&err];
    if (err) {
        CMLogError(@"coredata", @"fetch failed: %@", err);
        if (error) { *error = err; }
    }
    return out;
}

@end
