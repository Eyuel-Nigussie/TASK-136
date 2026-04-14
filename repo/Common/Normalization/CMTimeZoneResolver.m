//
//  CMTimeZoneResolver.m
//  CourierMatch
//

#import "CMTimeZoneResolver.h"

@interface CMTimeZoneResolver ()
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *map;
@property (nonatomic, copy)   NSString *fallbackId;
@end

@implementation CMTimeZoneResolver

+ (instancetype)shared {
    static CMTimeZoneResolver *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMTimeZoneResolver new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"ZipToTimeZone"
                                             withExtension:@"plist"];
        NSDictionary *d = url ? [NSDictionary dictionaryWithContentsOfURL:url] : nil;
        _map = d ?: @{};
        _fallbackId = _map[@"default"] ?: @"America/New_York";
    }
    return self;
}

- (NSString *)identifierForZip:(NSString *)zip {
    if (zip.length < 3) { return nil; }
    NSString *prefix = [zip substringToIndex:3];
    NSString *id_ = self.map[prefix];
    if ([id_ isEqualToString:@"default"]) { return nil; }
    return id_;
}

- (NSTimeZone *)timeZoneForZip:(NSString *)zip {
    NSString *id_ = [self identifierForZip:zip];
    NSTimeZone *tz = id_ ? [NSTimeZone timeZoneWithName:id_] : nil;
    if (!tz) {
        tz = [NSTimeZone timeZoneWithName:self.fallbackId] ?: [NSTimeZone localTimeZone];
    }
    return tz;
}

@end
