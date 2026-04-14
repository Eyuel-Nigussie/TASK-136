//
//  CMFileProtection.m
//  CourierMatch
//

#import "CMFileProtection.h"

@implementation CMFileProtection

+ (NSFileProtectionType)foundationValue:(CMProtectionClass)klass {
    switch (klass) {
        case CMProtectionClassComplete:
            return NSFileProtectionComplete;
        case CMProtectionClassCompleteUntilFirstUserAuth:
            return NSFileProtectionCompleteUntilFirstUserAuthentication;
        case CMProtectionClassCompleteUnlessOpen:
            return NSFileProtectionCompleteUnlessOpen;
        case CMProtectionClassNone:
            return NSFileProtectionNone;
    }
    return NSFileProtectionComplete;
}

+ (BOOL)apply:(CMProtectionClass)klass toURL:(NSURL *)url error:(NSError **)error {
    if (!url) { return NO; }
    NSDictionary *attrs = @{ NSFileProtectionKey: [self foundationValue:klass] };
    return [[NSFileManager defaultManager] setAttributes:attrs
                                            ofItemAtPath:url.path
                                                   error:error];
}

@end
