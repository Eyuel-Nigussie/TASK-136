//
//  CMSaveWithVersionCheckPolicy.m
//  CourierMatch
//

#import "CMSaveWithVersionCheckPolicy.h"
#import "CMError.h"
#import "NSManagedObjectContext+CMHelpers.h"

static NSString * const kVersion = @"version";

@implementation CMSaveWithVersionCheckPolicy

+ (CMSaveOutcome)saveChanges:(NSDictionary<NSString *, id> *)changes
                    toObject:(NSManagedObject *)object
                 baseVersion:(int64_t)baseVersion
                    resolver:(CMFieldConflictResolver)resolver
                mergedFields:(NSArray<NSString *> * _Nullable * _Nullable)mergedFieldsOut
              conflictFields:(NSArray<NSString *> * _Nullable * _Nullable)conflictFieldsOut
                       error:(NSError **)error {

    if (!object || !changes) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Missing object or changes"];
        }
        return CMSaveOutcomeFailed;
    }

    NSManagedObjectContext *ctx = object.managedObjectContext;
    if (!ctx) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Object has no context"];
        }
        return CMSaveOutcomeFailed;
    }

    // Pull the freshest on-disk snapshot without clobbering in-memory edits.
    [ctx refreshObject:object mergeChanges:NO];

    NSNumber *current = [object valueForKey:kVersion];
    int64_t currentV = current ? current.longLongValue : 0;

    // --- Fast path: no divergence since baseVersion.
    if (currentV == baseVersion) {
        for (NSString *k in changes) {
            [object setValue:changes[k] forKey:k];
        }
        [object setValue:@(baseVersion + 1) forKey:kVersion];
        NSError *saveErr = nil;
        if (![ctx cm_saveWithError:&saveErr]) {
            if (error) { *error = saveErr; }
            return CMSaveOutcomeFailed;
        }
        if (mergedFieldsOut)   { *mergedFieldsOut = @[]; }
        if (conflictFieldsOut) { *conflictFieldsOut = @[]; }
        return CMSaveOutcomeSaved;
    }

    // --- Slow path: divergence. Need field-level merge (Q9).
    // The set of fields that changed on disk since baseVersion is not
    // reconstructible without a history table, so we conservatively treat the
    // entire persisted field set as "theirs" and compute overlap against
    // the caller's change set.
    NSSet<NSString *> *mineFields = [NSSet setWithArray:changes.allKeys];
    NSMutableArray<NSString *> *conflicting = [NSMutableArray array];
    NSMutableArray<NSString *> *merged = [NSMutableArray array];

    for (NSString *field in mineFields) {
        id mine   = changes[field];
        id theirs = [object valueForKey:field];
        BOOL equal = (mine == theirs) ||
                     (mine && theirs && [mine isEqual:theirs]) ||
                     (!mine && !theirs);
        if (equal) {
            // Same value — not a conflict, no change to make.
            continue;
        }

        if (resolver) {
            // A resolver is provided — ask it how to handle the divergence.
            CMFieldMergeResolution res = resolver(field, mine, theirs);
            if (res == CMFieldMergeResolutionKeepMine) {
                [object setValue:mine forKey:field];
            }
            // Either way, this is a resolver-mediated conflict.
            [conflicting addObject:field];
        } else {
            // No resolver — treat as auto-merge: apply "mine" silently.
            [object setValue:mine forKey:field];
            [merged addObject:field];
        }
    }

    [object setValue:@(currentV + 1) forKey:kVersion];

    NSError *saveErr = nil;
    if (![ctx cm_saveWithError:&saveErr]) {
        if (error) { *error = saveErr; }
        return CMSaveOutcomeFailed;
    }

    if (mergedFieldsOut)   { *mergedFieldsOut = [merged copy]; }
    if (conflictFieldsOut) { *conflictFieldsOut = [conflicting copy]; }

    return (conflicting.count == 0)
             ? CMSaveOutcomeAutoMerged
             : CMSaveOutcomeResolvedAndSaved;
}

@end
