//
//  NSManagedObjectContext+CMHelpers.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSManagedObjectContext (CMHelpers)

/// Wraps `save:` with logging and surfaces NSMergePolicy conflicts through the
/// returned error. Safe to call when `hasChanges` is NO (returns YES immediately).
- (BOOL)cm_saveWithError:(NSError **)error;

/// Executes a fetch request and returns the array or nil on failure.
- (nullable NSArray *)cm_executeFetch:(NSFetchRequest *)request error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
