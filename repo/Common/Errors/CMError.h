//
//  CMError.h
//  CourierMatch
//

#import <Foundation/Foundation.h>
#import "CMErrorCodes.h"

NS_ASSUME_NONNULL_BEGIN

/// Structured NSError factory for `CMErrorDomain`.
@interface CMError : NSObject

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message;

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message
                  userInfo:(nullable NSDictionary<NSString *, id> *)userInfo;

+ (NSError *)errorWithCode:(CMErrorCode)code
                   message:(NSString *)message
           underlyingError:(nullable NSError *)underlying;

@end

NS_ASSUME_NONNULL_END
