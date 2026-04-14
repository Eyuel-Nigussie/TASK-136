//
//  CMPermissionMatrix.m
//  CourierMatch
//

#import "CMPermissionMatrix.h"

@interface CMPermissionMatrix ()
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *matrix;
@end

@implementation CMPermissionMatrix

+ (instancetype)shared {
    static CMPermissionMatrix *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMPermissionMatrix alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"PermissionMatrix" ofType:@"plist"];
        if (path) {
            NSDictionary *raw = [NSDictionary dictionaryWithContentsOfFile:path];
            if (raw) {
                _matrix = [raw copy];
            } else {
                _matrix = @{};
            }
        } else {
            _matrix = @{};
        }
    }
    return self;
}

- (BOOL)hasPermission:(NSString *)action forRole:(NSString *)role {
    if (!action || !role) return NO;
    NSArray<NSString *> *allowed = self.matrix[role];
    if (!allowed) return NO;
    return [allowed containsObject:action];
}

- (NSArray<NSString *> *)allowedActionsForRole:(NSString *)role {
    if (!role) return @[];
    NSArray<NSString *> *allowed = self.matrix[role];
    return allowed ? [allowed copy] : @[];
}

@end
