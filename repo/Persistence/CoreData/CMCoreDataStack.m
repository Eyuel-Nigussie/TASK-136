//
//  CMCoreDataStack.m
//  CourierMatch
//

#import "CMCoreDataStack.h"
#import "CMEncryptedValueTransformer.h"
#import "CMAddressTransformer.h"
#import "CMFileLocations.h"
#import "CMError.h"
#import "CMDebugLogger.h"

static NSString * const kModelName = @"CourierMatch";
static NSString * const kMainConfig = @"Main";
static NSString * const kWorkConfig = @"Work";

@interface CMCoreDataStack ()
@property (nonatomic, strong, readwrite) NSPersistentContainer *container;
@property (nonatomic, assign, readwrite) BOOL isLoaded;
@end

@implementation CMCoreDataStack

+ (instancetype)shared {
    static CMCoreDataStack *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMCoreDataStack new]; });
    return s;
}

#ifdef DEBUG
+ (void)resetSharedForTesting {
    // Replace the singleton with a fresh instance.
    static CMCoreDataStack *s;
    static dispatch_once_t once;
    // We need to reset the dispatch_once token. Since we can't do that directly,
    // we instead directly set the static variable. Access via the shared method
    // after this call will still return the old instance, so we overwrite the
    // internal pointer.
    CMCoreDataStack *fresh = [CMCoreDataStack new];
    // Use the same static pointer as +shared by going through it.
    // The simplest approach: reset isLoaded and container on the existing instance.
    CMCoreDataStack *existing = [self shared];
    existing.container = nil;
    existing.isLoaded = NO;
}
#endif

- (instancetype)init {
    if ((self = [super init])) {
        [CMEncryptedValueTransformer registerTransformer];
        [CMAddressTransformer registerTransformers];
    }
    return self;
}

- (NSPersistentStoreDescription *)descriptionForURL:(NSURL *)url
                                        configuration:(NSString *)config
                                      protectionClass:(NSFileProtectionType)prot {
    NSPersistentStoreDescription *d = [[NSPersistentStoreDescription alloc] initWithURL:url];
    d.type = NSSQLiteStoreType;
    d.configuration = config;
    d.shouldAddStoreAsynchronously = NO;
    d.shouldMigrateStoreAutomatically = YES;
    d.shouldInferMappingModelAutomatically = YES;
    [d setOption:prot forKey:NSPersistentStoreFileProtectionKey];
    // Reasonable SQLite tuning for mixed read/write workload.
    [d setOption:@{@"journal_mode": @"WAL"} forKey:NSSQLitePragmasOption];
    return d;
}

- (BOOL)loadStoresWithError:(NSError **)error {
    if (self.isLoaded) { return YES; }

    NSPersistentContainer *c = [NSPersistentContainer persistentContainerWithName:kModelName];
    if (!c || c.managedObjectModel.entities.count == 0 && c.managedObjectModel.configurations.count == 0) {
        // Model might still be empty during Step 2; that's fine for stack wiring.
    }

    NSPersistentStoreDescription *main = [self descriptionForURL:[CMFileLocations mainStoreURL]
                                                    configuration:kMainConfig
                                                  protectionClass:NSFileProtectionComplete];
    NSPersistentStoreDescription *work = [self descriptionForURL:[CMFileLocations sidecarStoreURL]
                                                    configuration:kWorkConfig
                                                  protectionClass:NSFileProtectionCompleteUntilFirstUserAuthentication];
    c.persistentStoreDescriptions = @[main, work];

    __block NSError *loadError = nil;
    __block NSUInteger loaded = 0;
    [c loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *desc, NSError *err) {
        if (err) {
            CMLogError(@"coredata", @"store load failed: %@", err);
            if (!loadError) { loadError = err; }
        } else {
            loaded++;
        }
    }];

    if (loadError) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeCoreDataBootFailed
                                    message:@"Core Data failed to load one or more stores"
                            underlyingError:loadError];
        }
        return NO;
    }

    c.viewContext.automaticallyMergesChangesFromParent = YES;
    c.viewContext.mergePolicy = [[NSMergePolicy alloc] initWithMergeType:NSErrorMergePolicyType];

    self.container = c;
    self.isLoaded = YES;
    CMLogInfo(@"coredata", @"loaded %lu store(s)", (unsigned long)loaded);
    return YES;
}

- (NSManagedObjectContext *)viewContext {
    return self.container.viewContext;
}

#ifdef DEBUG
- (BOOL)loadInMemoryStoreWithModel:(NSManagedObjectModel *)model
                             error:(NSError **)error {
    if (self.isLoaded) {
        // Already loaded; reset first.
        self.container = nil;
        self.isLoaded = NO;
    }

    if (!model) {
        // Try loading from bundles
        for (NSBundle *bundle in [NSBundle allBundles]) {
            NSURL *modelURL = [bundle URLForResource:kModelName withExtension:@"momd"];
            if (modelURL) {
                model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
                if (model) break;
            }
        }
    }
    if (!model) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeCoreDataBootFailed
                                    message:@"No managed object model available"];
        }
        return NO;
    }

    NSPersistentContainer *c = [[NSPersistentContainer alloc] initWithName:kModelName
                                                       managedObjectModel:model];
    NSPersistentStoreDescription *desc = [[NSPersistentStoreDescription alloc] init];
    desc.type = NSInMemoryStoreType;
    desc.shouldAddStoreAsynchronously = NO;
    c.persistentStoreDescriptions = @[desc];

    __block NSError *loadError = nil;
    [c loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *d, NSError *err) {
        if (err) { loadError = err; }
    }];

    if (loadError) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeCoreDataBootFailed
                                    message:@"In-memory store load failed"
                            underlyingError:loadError];
        }
        return NO;
    }

    c.viewContext.automaticallyMergesChangesFromParent = YES;
    c.viewContext.mergePolicy = [[NSMergePolicy alloc] initWithMergeType:NSOverwriteMergePolicyType];

    self.container = c;
    self.isLoaded = YES;
    return YES;
}
#endif

- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *))block {
    [self.container performBackgroundTask:^(NSManagedObjectContext *ctx) {
        ctx.mergePolicy = [[NSMergePolicy alloc] initWithMergeType:NSErrorMergePolicyType];
        if (block) { block(ctx); }
    }];
}

@end
