//
//  CMAddressTransformer.m
//  CourierMatch
//

#import "CMAddressTransformer.h"
#import "CMAddress.h"

NSValueTransformerName const CMAddressTransformerName      = @"CMAddressTransformer";
NSValueTransformerName const CMAddressArrayTransformerName = @"CMAddressArrayTransformer";

@implementation CMAddressTransformer

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[[CMAddress class]];
}

+ (void)registerTransformers {
    [NSValueTransformer setValueTransformer:[CMAddressTransformer new]
                                     forName:CMAddressTransformerName];
    [NSValueTransformer setValueTransformer:[CMAddressArrayTransformer new]
                                     forName:CMAddressArrayTransformerName];
}

@end

@implementation CMAddressArrayTransformer

+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[[NSArray class], [CMAddress class]];
}

@end
