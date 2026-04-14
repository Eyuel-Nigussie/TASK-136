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

    // Phase 1: Detect conflicts WITHOUT committing any changes.
    // Use a "detect-only" resolver that captures both sides but returns KeepTheirs
    // so the object remains at the server's state (no user changes applied yet).
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
                                 // Capture both values for UI display.
                                 if (theirs) theirValues[field] = theirs;
                                 if (mine)   mineValues[field]  = mine;
                                 // Keep theirs for now — do NOT apply user changes yet.
                                 return CMFieldMergeResolutionKeepTheirs;
                             }
                             mergedFields:&mergedFields
                             conflictFields:&conflictFields
                             error:&error];

    switch (outcome) {
        case CMSaveOutcomeSaved:
        case CMSaveOutcomeAutoMerged:
            // No conflicts — changes applied cleanly.
            CMLogInfo(@"versioncheck.ui", @"Save succeeded (outcome=%ld)", (long)outcome);
            if (completion) completion(YES);
            return;

        case CMSaveOutcomeResolvedAndSaved:
            // Conflicts were detected; object currently holds server values.
            // Present the choice to the user BEFORE committing either side.
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

    // If no actual conflict fields, the auto-merge handled everything.
    if (!conflictFields || conflictFields.count == 0) {
        if (completion) completion(YES);
        return;
    }

    // Phase 2: Present the conflict choice BEFORE applying user's changes.
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
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Mine for %lu fields",
                      (unsigned long)conflictFields.count);
            // Now apply user's values for the conflicting fields.
            NSMutableDictionary *userChanges = [NSMutableDictionary dictionary];
            for (NSString *field in conflictFields) {
                id mine = mineValues[field];
                if (mine) {
                    userChanges[field] = mine;
                }
            }
            if (userChanges.count > 0) {
                NSNumber *curV = [object valueForKey:@"version"];
                int64_t currentVersion = curV ? curV.longLongValue : 0;
                NSError *applyErr = nil;
                [CMSaveWithVersionCheckPolicy saveChanges:userChanges
                                                 toObject:object
                                              baseVersion:currentVersion
                                                 resolver:nil
                                             mergedFields:NULL
                                           conflictFields:NULL
                                                    error:&applyErr];
                if (applyErr) {
                    CMLogError(@"versioncheck.ui", @"Apply mine failed: %@", applyErr);
                }
            }
            if (completion) completion(YES);
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Keep Theirs"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            CMLogInfo(@"versioncheck.ui", @"User chose Keep Theirs for %lu fields",
                      (unsigned long)conflictFields.count);
            // Server values are already in place — nothing to do.
            if (completion) completion(YES);
        }]];

        [viewController presentViewController:alert animated:YES completion:nil];
    });
}

@end
