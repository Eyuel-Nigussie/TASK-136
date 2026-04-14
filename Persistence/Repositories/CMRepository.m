//
//  CMRepository.m
//  CourierMatch
//

#import "CMRepository.h"
#import "CMTenantContext.h"
#import "CMCoreDataStack.h"
#import "CMError.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMRepository

+ (NSString *)entityName {
    [NSException raise:NSInternalInconsistencyException
                format:@"%@ must override +entityName", NSStringFromClass(self)];
    return nil;
}

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    if ((self = [super init])) {
        _context = context ?: [CMCoreDataStack shared].viewContext;
    }
    return self;
}

- (NSFetchRequest *)scopedFetchRequest {
    return [self scopedFetchRequestWithPredicate:nil];
}

- (NSFetchRequest *)scopedFetchRequestWithPredicate:(NSPredicate *)predicate {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:[[self class] entityName]];
    NSPredicate *scope = [[CMTenantContext shared] scopingPredicate];
    if (scope && predicate) {
        req.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[scope, predicate]];
    } else if (scope) {
        req.predicate = scope;
    } else if (predicate) {
        req.predicate = predicate;
    }
    return req;
}

- (NSArray *)fetchWithPredicate:(NSPredicate *)predicate
                  sortDescriptors:(NSArray<NSSortDescriptor *> *)sorts
                            limit:(NSUInteger)limit
                            error:(NSError **)error {
    if (![[CMTenantContext shared] isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeTenantScopingViolation
                                    message:@"No tenant context — refusing unscoped fetch"];
        }
        return nil;
    }
    NSFetchRequest *req = [self scopedFetchRequestWithPredicate:predicate];
    req.sortDescriptors = sorts;
    if (limit > 0) { req.fetchLimit = limit; }
    return [self.context cm_executeFetch:req error:error];
}

- (id)fetchOneWithPredicate:(NSPredicate *)predicate error:(NSError **)error {
    NSArray *r = [self fetchWithPredicate:predicate sortDescriptors:nil limit:1 error:error];
    return r.firstObject;
}

- (NSManagedObject *)insertStampedObject {
    NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:[[self class] entityName]
                                                         inManagedObjectContext:self.context];
    NSDate *now = [NSDate date];
    NSString *uid = [[NSUUID UUID] UUIDString];
    CMTenantContext *tc = [CMTenantContext shared];
    NSEntityDescription *entity = obj.entity;
    NSDictionary *attrs = entity.attributesByName;

    if (attrs[@"tenantId"])  { [obj setValue:tc.currentTenantId forKey:@"tenantId"]; }
    if (attrs[@"createdAt"]) { [obj setValue:now                forKey:@"createdAt"]; }
    if (attrs[@"updatedAt"]) { [obj setValue:now                forKey:@"updatedAt"]; }
    if (attrs[@"createdBy"]) { [obj setValue:tc.currentUserId   forKey:@"createdBy"]; }
    if (attrs[@"updatedBy"]) { [obj setValue:tc.currentUserId   forKey:@"updatedBy"]; }
    if (attrs[@"version"])   { [obj setValue:@(1)               forKey:@"version"]; }

    // Stamp the entity-specific UUID primary key if present (e.g. `orderId`).
    NSString *idKey = [NSString stringWithFormat:@"%@Id",
                       [[entity.name substringToIndex:1].lowercaseString
                          stringByAppendingString:[entity.name substringFromIndex:1]]];
    if (attrs[idKey] && ![obj valueForKey:idKey]) {
        [obj setValue:uid forKey:idKey];
    }
    return obj;
}

@end
