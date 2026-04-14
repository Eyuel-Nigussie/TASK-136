//
//  CMIDMasker.m
//  CourierMatch
//

#import "CMIDMasker.h"

@implementation CMIDMasker

+ (NSString *)maskTrailing:(NSString *)value visibleTail:(NSUInteger)tail {
    if (!value) { return @""; }
    NSUInteger n = value.length;
    if (n == 0) { return @""; }
    if (tail >= n) { return value; }
    NSString *stars = [@"" stringByPaddingToLength:(n - tail) withString:@"*" startingAtIndex:0];
    return [stars stringByAppendingString:[value substringFromIndex:(n - tail)]];
}

+ (NSString *)ssnStyle:(NSString *)value {
    if (!value) { return @""; }
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digits = [[value componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    if (digits.length < 4) { return @"***-**-****"; }
    NSString *tail = [digits substringFromIndex:(digits.length - 4)];
    return [NSString stringWithFormat:@"***-**-%@", tail];
}

+ (NSString *)emailStyle:(NSString *)value {
    NSRange at = [value rangeOfString:@"@"];
    if (at.location == NSNotFound) { return @"****"; }
    NSString *domain = [value substringFromIndex:at.location];
    return [NSString stringWithFormat:@"****%@", domain];
}

+ (NSString *)phoneStyle:(NSString *)value {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digits = [[value componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    if (digits.length < 4) { return @"(***) ***-**-**"; }
    NSString *last4 = [digits substringFromIndex:(digits.length - 4)];
    NSString *a = [last4 substringToIndex:2];
    NSString *b = [last4 substringFromIndex:2];
    return [NSString stringWithFormat:@"(***) ***-%@-%@", a, b];
}

@end
