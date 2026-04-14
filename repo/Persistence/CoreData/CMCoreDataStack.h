//
//  CMCoreDataStack.h
//  CourierMatch
//
//  Boot a two-store NSPersistentContainer per design.md §2.3 / Q7:
//      Main   — CourierMatch.sqlite  (NSFileProtectionComplete)
//      Work   — work.sqlite          (NSFileProtectionCompleteUntilFirstUserAuthentication)
//  `viewContext` runs on main; writes use `performBackgroundTask:`.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMCoreDataStack : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSPersistentContainer *container;
@property (nonatomic, strong, readonly) NSManagedObjectContext *viewContext;

/// Synchronously loads both stores. Call exactly once, off the main thread,
/// before any repository fetches.
- (BOOL)loadStoresWithError:(NSError **)error;

/// Enqueues a block on a private-queue background context. Changes are saved
/// automatically on successful return. Block signature matches NSPersistentContainer.
- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *ctx))block;

/// Returns YES iff the stores have been loaded.
@property (nonatomic, readonly) BOOL isLoaded;

#ifdef DEBUG
/// Resets the shared instance so it can be reconfigured (testing only).
+ (void)resetSharedForTesting;

/// Loads a single in-memory store using the given model (testing only).
/// If model is nil, the CourierMatch model is loaded from the test bundle.
- (BOOL)loadInMemoryStoreWithModel:(nullable NSManagedObjectModel *)model
                             error:(NSError **)error;
#endif

@end

NS_ASSUME_NONNULL_END
