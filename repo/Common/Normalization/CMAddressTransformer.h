//
//  CMAddressTransformer.h
//  CourierMatch
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSValueTransformerName const CMAddressTransformerName;
extern NSValueTransformerName const CMAddressArrayTransformerName;

@interface CMAddressTransformer : NSSecureUnarchiveFromDataTransformer
+ (void)registerTransformers;
@end

@interface CMAddressArrayTransformer : NSSecureUnarchiveFromDataTransformer
@end

NS_ASSUME_NONNULL_END
