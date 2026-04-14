//
//  CMPasswordPolicy.m
//  CourierMatch
//

#import "CMPasswordPolicy.h"

@interface CMPasswordPolicy ()
@property (nonatomic, strong) NSSet<NSString *> *blocklist;
@property (nonatomic, strong, readwrite) NSCharacterSet *symbolClass;
@property (nonatomic, assign, readwrite) NSUInteger minimumLength;
@end

@implementation CMPasswordPolicy

+ (instancetype)shared {
    static CMPasswordPolicy *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMPasswordPolicy new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _minimumLength = 12;
        NSMutableCharacterSet *sym = [NSMutableCharacterSet new];
        [sym formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        _symbolClass = [sym invertedSet];

        NSURL *url = [[NSBundle mainBundle] URLForResource:@"CMCommonPasswords"
                                             withExtension:@"plist"];
        NSArray *list = url ? [NSArray arrayWithContentsOfURL:url] : @[];
        _blocklist = [NSSet setWithArray:(list ?: @[])];
    }
    return self;
}

- (BOOL)containsDigit:(NSString *)s {
    return [s rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
}

- (BOOL)containsSymbol:(NSString *)s {
    return [s rangeOfCharacterFromSet:self.symbolClass].location != NSNotFound;
}

- (CMPasswordViolation)evaluate:(NSString *)password {
    if (!password || password.length == 0) { return CMPasswordViolationEmpty; }
    CMPasswordViolation v = CMPasswordViolationNone;
    if (password.length < self.minimumLength) { v |= CMPasswordViolationTooShort; }
    if (![self containsDigit:password])       { v |= CMPasswordViolationMissingDigit; }
    if (![self containsSymbol:password])      { v |= CMPasswordViolationMissingSymbol; }
    if ([self.blocklist containsObject:password]) { v |= CMPasswordViolationBlocklisted; }
    return v;
}

- (NSString *)summaryForViolations:(CMPasswordViolation)v {
    if (v == CMPasswordViolationNone) { return @""; }
    NSMutableArray *parts = [NSMutableArray array];
    if (v & CMPasswordViolationEmpty)         { [parts addObject:@"Password is empty"]; }
    if (v & CMPasswordViolationTooShort)      { [parts addObject:[NSString stringWithFormat:@"Must be at least %lu characters", (unsigned long)self.minimumLength]]; }
    if (v & CMPasswordViolationMissingDigit)  { [parts addObject:@"Needs at least one digit"]; }
    if (v & CMPasswordViolationMissingSymbol) { [parts addObject:@"Needs at least one symbol"]; }
    if (v & CMPasswordViolationBlocklisted)   { [parts addObject:@"Too common — choose a different password"]; }
    return [parts componentsJoinedByString:@"; "];
}

@end
