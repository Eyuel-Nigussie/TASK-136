//
//  CMSaveWithVersionCheckPolicy.h
//  CourierMatch
//
//  Optimistic locking + field-level merge (questions.md Q9).
//
//  Usage:
//      CMSaveOutcome out = [CMSaveWithVersionCheckPolicy
//              saveChanges:changesDict
//                 toObject:managedObject
//             baseVersion:v
//                resolver:^CMFieldMergeResolution(NSString *field, id mine, id theirs) { ... }
//                    error:&err];
//
//  Behavior:
//  - If current `version` equals `baseVersion` → apply all changes, bump version.
//  - Else, compute the set of fields the caller changed vs the set that
//    diverged on disk since baseVersion. Disjoint sets → auto-merge.
//    Overlapping fields → invoke `resolver` to pick Keep Mine / Keep Theirs
//    per conflicting field.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMFieldMergeResolution) {
    CMFieldMergeResolutionKeepMine   = 0,
    CMFieldMergeResolutionKeepTheirs = 1,
};

typedef NS_ENUM(NSInteger, CMSaveOutcome) {
    CMSaveOutcomeSaved            = 0,
    CMSaveOutcomeAutoMerged       = 1,   // disjoint field sets; saved
    CMSaveOutcomeResolvedAndSaved = 2,   // overlapping fields; resolver consulted
    CMSaveOutcomeFailed           = 3,
};

typedef CMFieldMergeResolution (^CMFieldConflictResolver)(NSString *field, id _Nullable mine, id _Nullable theirs);

@interface CMSaveWithVersionCheckPolicy : NSObject

/// `changes` maps attribute name → new value. The object's `version` attribute
/// is read and bumped by this method.
+ (CMSaveOutcome)saveChanges:(NSDictionary<NSString *, id> *)changes
                    toObject:(NSManagedObject *)object
                 baseVersion:(int64_t)baseVersion
                    resolver:(nullable CMFieldConflictResolver)resolver
                mergedFields:(NSArray<NSString *> * _Nullable * _Nullable)mergedFieldsOut
              conflictFields:(NSArray<NSString *> * _Nullable * _Nullable)conflictFieldsOut
                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
