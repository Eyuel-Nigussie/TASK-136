//
//  CMRepository.h
//  CourierMatch
//
//  Base repository. Every fetch is tenant-scoped via CMTenantContext —
//  concrete repositories inherit and only declare their `entityName`.
//  See design.md §2.1.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMRepository : NSObject

/// Concrete subclasses must override to return the Core Data entity name.
+ (NSString *)entityName;

/// Default context is `CMCoreDataStack.shared.viewContext` (main-thread reads).
/// Tests / background writers pass a private-queue context.
- (instancetype)initWithContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) NSManagedObjectContext *context;

/// Returns a fetch request with the tenant-scoping predicate from
/// `CMTenantContext.shared` already applied. Callers may compose with `AND`.
- (NSFetchRequest *)scopedFetchRequest;

/// Appends the given predicate to the tenant-scope predicate via `AND`.
- (NSFetchRequest *)scopedFetchRequestWithPredicate:(nullable NSPredicate *)predicate;

/// Fetch helper; returns nil on error.
- (nullable NSArray *)fetchWithPredicate:(nullable NSPredicate *)predicate
                           sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sorts
                                     limit:(NSUInteger)limit
                                     error:(NSError **)error;

/// Fetches exactly one object matching the predicate, or nil if none.
- (nullable id)fetchOneWithPredicate:(nullable NSPredicate *)predicate
                               error:(NSError **)error;

/// Inserts a new managed object for this entity and stamps tenantId,
/// createdAt, updatedAt, createdBy, updatedBy, version = 1.
- (__kindof NSManagedObject *)insertStampedObject;

@end

NS_ASSUME_NONNULL_END
