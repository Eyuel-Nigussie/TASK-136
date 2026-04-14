//
//  CMAddressNormalizer.m
//  CourierMatch
//

#import "CMAddressNormalizer.h"

@implementation CMNormalizedAddress
@end

@interface CMAddressNormalizer ()
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *stateMap;
@property (nonatomic, strong) NSSet<NSString *> *abbrSet;
@property (nonatomic, strong) NSRegularExpression *zipRegex;
@end

@implementation CMAddressNormalizer

+ (instancetype)shared {
    static CMAddressNormalizer *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMAddressNormalizer new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"USStateAbbreviations"
                                             withExtension:@"plist"];
        _stateMap = url ? [NSDictionary dictionaryWithContentsOfURL:url] : @{};
        _abbrSet = [NSSet setWithArray:_stateMap.allValues];
        _zipRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\d{5}(-\\d{4})?$"
                                                              options:0
                                                                error:NULL];
    }
    return self;
}

- (BOOL)isValidZip:(NSString *)zip {
    if (!zip) { return NO; }
    NSString *z = [zip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSUInteger n = [self.zipRegex numberOfMatchesInString:z
                                                  options:0
                                                    range:NSMakeRange(0, z.length)];
    return n == 1;
}

- (NSString *)stateAbbrFromInput:(NSString *)input {
    if (!input) { return nil; }
    NSString *t = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (t.length == 0) { return nil; }
    NSString *upper = t.uppercaseString;
    if (upper.length == 2 && [self.abbrSet containsObject:upper]) {
        return upper;
    }
    NSString *key = t.lowercaseString;
    NSString *abbr = self.stateMap[key];
    return abbr;
}

- (NSString *)titleCase:(NSString *)s {
    if (!s) { return nil; }
    NSString *trimmed = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return [trimmed.capitalizedString copy];
}

- (CMNormalizedAddress *)normalizeLine1:(NSString *)line1
                                   line2:(NSString *)line2
                                    city:(NSString *)city
                                   state:(NSString *)state
                                     zip:(NSString *)zip {
    NSString *abbr = [self stateAbbrFromInput:state];
    if (!abbr) { return nil; }
    if (![self isValidZip:zip]) { return nil; }

    CMNormalizedAddress *a = [CMNormalizedAddress new];
    a.line1 = [line1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    a.line2 = [line2 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    a.city  = [self titleCase:city];
    a.stateAbbr = abbr;
    a.zip = [zip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    NSString *zip5 = [a.zip substringToIndex:MIN((NSUInteger)5, a.zip.length)];
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%@",
                     (a.line1 ?: @"").lowercaseString,
                     (a.city ?: @"").lowercaseString,
                     a.stateAbbr.lowercaseString,
                     zip5];
    a.normalizedKey = key;
    return a;
}

@end
