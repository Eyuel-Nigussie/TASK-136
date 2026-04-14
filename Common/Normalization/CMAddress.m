//
//  CMAddress.m
//  CourierMatch
//

#import "CMAddress.h"

@implementation CMAddress

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_line1      forKey:@"line1"];
    [coder encodeObject:_line2      forKey:@"line2"];
    [coder encodeObject:_city       forKey:@"city"];
    [coder encodeObject:_stateAbbr  forKey:@"stateAbbr"];
    [coder encodeObject:_zip        forKey:@"zip"];
    [coder encodeDouble:_lat        forKey:@"lat"];
    [coder encodeDouble:_lng        forKey:@"lng"];
    [coder encodeObject:_normalizedKey forKey:@"normalizedKey"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _line1         = [coder decodeObjectOfClass:[NSString class] forKey:@"line1"];
        _line2         = [coder decodeObjectOfClass:[NSString class] forKey:@"line2"];
        _city          = [coder decodeObjectOfClass:[NSString class] forKey:@"city"];
        _stateAbbr     = [coder decodeObjectOfClass:[NSString class] forKey:@"stateAbbr"];
        _zip           = [coder decodeObjectOfClass:[NSString class] forKey:@"zip"];
        _lat           = [coder decodeDoubleForKey:@"lat"];
        _lng           = [coder decodeDoubleForKey:@"lng"];
        _normalizedKey = [coder decodeObjectOfClass:[NSString class] forKey:@"normalizedKey"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    CMAddress *c = [CMAddress new];
    c.line1 = _line1; c.line2 = _line2; c.city = _city;
    c.stateAbbr = _stateAbbr; c.zip = _zip;
    c.lat = _lat; c.lng = _lng; c.normalizedKey = _normalizedKey;
    return c;
}

- (NSDictionary<NSString *, id> *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (_line1)         d[@"line1"]         = _line1;
    if (_line2)         d[@"line2"]         = _line2;
    if (_city)          d[@"city"]          = _city;
    if (_stateAbbr)     d[@"stateAbbr"]     = _stateAbbr;
    if (_zip)           d[@"zip"]           = _zip;
    d[@"lat"] = @(_lat);
    d[@"lng"] = @(_lng);
    if (_normalizedKey) d[@"normalizedKey"] = _normalizedKey;
    return d;
}

+ (instancetype)fromDictionary:(NSDictionary<NSString *, id> *)dict {
    if (!dict) return nil;
    CMAddress *a = [CMAddress new];
    a.line1         = dict[@"line1"];
    a.line2         = dict[@"line2"];
    a.city          = dict[@"city"];
    a.stateAbbr     = dict[@"stateAbbr"];
    a.zip           = dict[@"zip"];
    a.lat           = [dict[@"lat"] doubleValue];
    a.lng           = [dict[@"lng"] doubleValue];
    a.normalizedKey = dict[@"normalizedKey"];
    return a;
}

@end
