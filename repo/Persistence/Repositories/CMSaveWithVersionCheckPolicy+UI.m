//
//  CMSaveWithVersionCheckPolicy+UI.m
//  CourierMatch
//

#import "CMSaveWithVersionCheckPolicy+UI.h"
#import "CMDebugLogger.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMSaveWithVersionCheckPolicy (UI)

+ (void)saveChanges:(NSDictionary<NSString *, id> *)changes
           toObject:(NSManagedObject *)object
        baseVersion:(int64_t)baseVersion
fromViewController:(UIViewController *)viewController
         completion:(void (^)(BOOL saved))completion {

    // Phase 1: Dry-run conflict detection — NO save, NO version bump, NO mutation.
    NSArray<NSString *> *conflictFields = nil;
    NSDictionary<NSString *, id> *theirValues = nil;
    NSDictionary<NSString *, id> *mineValues = nil;

    BOOL hasConflict = [CMSaveWithVersionCheckPolicy
                        detectConflictsForChanges:changes
                        onObject:object
                        baseVersion:baseVersion
                        conflictFields:&conflictFields
                        theirValues:&theirValues
                        mineValues:&mineValues];

    if (!hasConflict) {
        // No conflict — apply changes and save directly.
        NSError *error = nil;
        CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                                 saveChanges:changes
                                 toObject:object
                                 baseVersion:baseVersion
                                 resolver:nil
                                 mergedFields:NULL
                                 conflictFields:NULL
                                 error:&error];
        if (outcome == CMSaveOutcomeFailed) {
            CMLogError(@"versioncheck.ui", @"Save failed: %@", error);
            if (viewController) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert =
                        [UIAlertController alertControllerWithTitle:@"Save Error"
                                                           message:error.localizedDescription ?: @"Failed to save."
                                                    preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                             style:UIAlertActionStyleDefault
                                                           handler:nil]];
                    [viewController presentViewController:alert animated:YES completion:nil];
                });
            }
            if (completion) completion(NO);
        } else {
            CMLogInfo(@"versioncheck.ui", @"Save succeeded (no conflicts)");
            if (completion) completion(YES);
        }
        return;
    }

    // Phase 2: Conflict detected. Present choice to user BEFORE any mutation.
    // At this point, NO changes have been applied to the object.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableString *message = [NSMutableString stringWithString:
            @"Another user changed the same fields you edited:\n\n"];
        for (NSString *field in conflictFields) {
            id theirs = theirValues[field];
            id mine = mineValues[field];
            [message appendFormat:@"  %@:\n    Yours = \"%@\"\n    Theirs = \"%@\"\n",
             field, mine ?: @"(empty)", theirs ?: @"(empty)"];
        }
        [message appendString:@"\nChoose which version to keep:"];

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"Conflict Detected"
                                               message:[message copy]
                                        preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"Keep Mine"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Mine");
            // Now apply user's changes with a resolver that forces KeepMine.
            NSNumber *curV = [object valueForKey:@"version"];
            int64_t currentVersion = curV ? curV.longLongValue : 0;
            NSError *saveErr = nil;
            CMSaveOutcome result = [CMSaveWithVersionCheckPolicy
                                    saveChanges:changes
                                    toObject:object
                                    baseVersion:currentVersion
                                    resolver:^CMFieldMergeResolution(NSString *f, id m, id t) {
                                        return CMFieldMergeResolutionKeepMine;
                                    }
                                    mergedFields:NULL
                                    conflictFields:NULL
                                    error:&saveErr];
            if (result == CMSaveOutcomeFailed) {
                CMLogError(@"versioncheck.ui", @"Keep Mine save failed: %@", saveErr);
            }
            if (completion) completion(result != CMSaveOutcomeFailed);
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Keep Theirs"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Theirs");
            // Server values are already on disk — nothing to write.
            // Just refresh the object to reflect the on-disk state.
            [object.managedObjectContext refreshObject:object mergeChanges:NO];
            if (completion) completion(YES);
        }]];

        [viewController presentViewController:alert animated:YES completion:nil];
    });
}

@end
