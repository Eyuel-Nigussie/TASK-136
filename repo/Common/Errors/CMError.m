//
//  CMError.m
//  CourierMatch
//

#import "CMError.h"

NSErrorDomain const CMErrorDomain = @"com.eaglepoint.couriermatch.error";

@implementation CMError

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message {
    return [self errorWithCode:code message:message userInfo:nil];
}

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message
                  userInfo:(NSDictionary<NSString *, id> *)userInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (userInfo) { [info addEntriesFromDictionary:userInfo]; }
    if (message) { info[NSLocalizedDescriptionKey] = message; }
    return [NSError errorWithDomain:CMErrorDomain code:code userInfo:info];
}

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message
           underlyingError:(NSError *)underlying {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (message) { info[NSLocalizedDescriptionKey] = message; }
    if (underlying) { info[NSUnderlyingErrorKey] = underlying; }
    return [NSError errorWithDomain:CMErrorDomain code:code userInfo:info];
}

@end
