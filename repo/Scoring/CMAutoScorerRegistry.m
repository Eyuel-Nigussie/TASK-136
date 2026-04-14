//
//  CMAutoScorerRegistry.m
//  CourierMatch
//

#import "CMAutoScorerRegistry.h"
#import "CMAutoScorer_OnTime.h"
#import "CMAutoScorer_PhotoAttached.h"
#import "CMAutoScorer_SignatureCaptured.h"

@interface CMAutoScorerRegistry ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<CMAutoScorerProtocol>> *scorers;
@end

@implementation CMAutoScorerRegistry

+ (instancetype)shared {
    static CMAutoScorerRegistry *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CMAutoScorerRegistry alloc] init];
        [instance registerBuiltInScorers];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scorers = [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Built-in Registration

- (void)registerBuiltInScorers {
    [self registerScorer:[[CMAutoScorer_OnTime alloc] init]
                  forKey:@"on_time_within_10min"];
    [self registerScorer:[[CMAutoScorer_PhotoAttached alloc] init]
                  forKey:@"photo_attached"];
    [self registerScorer:[[CMAutoScorer_SignatureCaptured alloc] init]
                  forKey:@"signature_captured"];
}

#pragma mark - Public API

- (void)registerScorer:(id<CMAutoScorerProtocol>)scorer forKey:(NSString *)key {
    NSParameterAssert(scorer);
    NSParameterAssert(key.length > 0);
    @synchronized (self.scorers) {
        self.scorers[key] = scorer;
    }
}

- (id<CMAutoScorerProtocol>)scorerForKey:(NSString *)key {
    @synchronized (self.scorers) {
        return self.scorers[key];
    }
}

- (NSArray<NSString *> *)allKeys {
    @synchronized (self.scorers) {
        return [self.scorers allKeys];
    }
}

@end
