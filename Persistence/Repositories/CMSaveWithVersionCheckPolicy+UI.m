//
//  CMSaveWithVersionCheckPolicy+UI.m
//  CourierMatch
//

#import "CMSaveWithVersionCheckPolicy+UI.h"
#import "CMDebugLogger.h"

@implementation CMSaveWithVersionCheckPolicy (UI)

+ (void)saveChanges:(NSDictionary<NSString *, id> *)changes
           toObject:(NSManagedObject *)object
        baseVersion:(int64_t)baseVersion
fromViewController:(UIViewController *)viewController
         completion:(void (^)(BOOL saved))completion {

    // First attempt: use a "keep mine" resolver so we can detect conflicts
    // without immediately committing the user's choice.
    NSMutableDictionary<NSString *, id> *theirValues = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, id> *mineValues  = [NSMutableDictionary dictionary];

    NSError *error = nil;
    NSArray<NSString *> *mergedFields = nil;
    NSArray<NSString *> *conflictFields = nil;

    CMSaveOutcome outcome = [CMSaveWithVersionCheckPolicy
                             saveChanges:changes
                             toObject:object
                             baseVersion:baseVersion
                             resolver:^CMFieldMergeResolution(NSString *field, id mine, id theirs) {
                                 // Capture values for potential UI display; default to keep mine.
                                 if (theirs) theirValues[field] = theirs;
                                 if (mine)   mineValues[field]  = mine;
                                 return CMFieldMergeResolutionKeepMine;
                             }
                             mergedFields:&mergedFields
                             conflictFields:&conflictFields
                             error:&error];

    switch (outcome) {
        case CMSaveOutcomeSaved:
        case CMSaveOutcomeAutoMerged:
            CMLogInfo(@"versioncheck.ui", @"Save succeeded (outcome=%ld)", (long)outcome);
            if (completion) completion(YES);
            return;

        case CMSaveOutcomeResolvedAndSaved:
            // Conflicts were resolved as "keep mine" automatically above.
            // Present alert to let user confirm or switch to "keep theirs".
            break;

        case CMSaveOutcomeFailed:
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
            return;
    }

    // If we reach here, there were conflicts that we auto-resolved as "keep mine".
    // Show an alert describing the conflicts so the user can accept or switch.
    if (!conflictFields || conflictFields.count == 0) {
        if (completion) completion(YES);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableString *message = [NSMutableString stringWithString:
            @"Another user changed the same fields you edited:\n\n"];
        for (NSString *field in conflictFields) {
            id theirs = theirValues[field];
            [message appendFormat:@"  %@: server value = \"%@\"\n", field,
             theirs ?: @"(empty)"];
        }
        [message appendString:@"\nYour changes have been applied. Choose an option:"];

        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"Conflict Detected"
                                               message:[message copy]
                                        preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"Keep Mine"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            // Already saved with "keep mine" above.
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Mine for %lu fields",
                      (unsigned long)conflictFields.count);
            if (completion) completion(YES);
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Keep Theirs"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Theirs for %lu fields",
                      (unsigned long)conflictFields.count);
            // Re-save with the server's values for conflicting fields.
            NSMutableDictionary *revertChanges = [NSMutableDictionary dictionary];
            for (NSString *field in conflictFields) {
                id theirs = theirValues[field];
                if (theirs) {
                    revertChanges[field] = theirs;
                }
            }
            if (revertChanges.count > 0) {
                // Read current version from object and do a fast-path save.
                NSNumber *curV = [object valueForKey:@"version"];
                int64_t currentVersion = curV ? curV.longLongValue : 0;
                NSError *revertErr = nil;
                [CMSaveWithVersionCheckPolicy saveChanges:revertChanges
                                                 toObject:object
                                              baseVersion:currentVersion
                                                 resolver:nil
                                             mergedFields:NULL
                                           conflictFields:NULL
                                                    error:&revertErr];
                if (revertErr) {
                    CMLogError(@"versioncheck.ui", @"Revert to theirs failed: %@", revertErr);
                }
            }
            if (completion) completion(YES);
        }]];

        [viewController presentViewController:alert animated:YES completion:nil];
    });
}

@end
