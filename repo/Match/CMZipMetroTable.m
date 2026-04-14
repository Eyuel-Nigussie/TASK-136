//
//  CMZipMetroTable.m
//  CourierMatch
//

#import "CMZipMetroTable.h"

@interface CMZipMetroTable ()
@property (nonatomic, strong) NSSet<NSString *> *metroPrefixes;
@end

@implementation CMZipMetroTable

+ (instancetype)shared {
    static CMZipMetroTable *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[CMZipMetroTable alloc] init]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _urbanMultiplier = 1.35;
        _ruralMultiplier = 1.15;
        [self loadPrefixes];
    }
    return self;
}

- (void)loadPrefixes {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MetroZipPrefixes"
                                                    ofType:@"plist"];
    NSArray<NSString *> *prefixes = nil;
    if (path) {
        prefixes = [NSArray arrayWithContentsOfFile:path];
    }
    if (prefixes.count > 0) {
        self.metroPrefixes = [NSSet setWithArray:prefixes];
    } else {
        // Fallback: hardcoded core prefixes if plist is missing (e.g., unit tests).
        self.metroPrefixes = [NSSet setWithArray:@[
            // NYC
            @"100", @"101", @"102", @"103", @"104",
            @"110", @"111", @"112", @"113", @"114",
            // LA
            @"900", @"901", @"902", @"903", @"904",
            @"905", @"906", @"907", @"908",
            @"910", @"911", @"912", @"913", @"914",
            // Chicago
            @"606", @"607", @"608",
            // SF
            @"940", @"941", @"943", @"944", @"945",
            @"946", @"947", @"948", @"949", @"950", @"951",
            // Boston
            @"021", @"022",
            // DC
            @"200", @"201", @"202", @"203", @"204", @"205",
            // Philly
            @"190", @"191",
            // Houston
            @"770", @"771", @"772", @"773",
            // Dallas
            @"750", @"751", @"752", @"753",
            // Miami
            @"331", @"332", @"333",
            // Seattle
            @"980", @"981",
            // Denver
            @"802",
            // Atlanta
            @"303", @"304",
            // Minneapolis
            @"553", @"554",
            // Detroit
            @"481", @"482",
        ]];
    }
}

- (BOOL)isMetroZip:(NSString *)zip {
    if (!zip || zip.length < 3) {
        return NO;
    }
    NSString *prefix = [zip substringToIndex:3];
    return [self.metroPrefixes containsObject:prefix];
}

- (BOOL)areBothMetroZip1:(NSString *)zip1 zip2:(NSString *)zip2 {
    return [self isMetroZip:zip1] && [self isMetroZip:zip2];
}

- (double)multiplierForBothMetro:(BOOL)bothMetro {
    return bothMetro ? self.urbanMultiplier : self.ruralMultiplier;
}

@end
