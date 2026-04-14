//
//  CMFileProtection.h
//  CourierMatch
//
//  Applies iOS data-protection classes to files and directories.
//  See design.md §3.3, §11.3, questions.md Q7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CMProtectionClass) {
    CMProtectionClassComplete = 0,                       // NSFileProtectionComplete
    CMProtectionClassCompleteUntilFirstUserAuth = 1,     // NSFileProtectionCompleteUntilFirstUserAuthentication
    CMProtectionClassCompleteUnlessOpen = 2,             // NSFileProtectionCompleteUnlessOpen
    CMProtectionClassNone = 3,                           // NSFileProtectionNone (rarely used here)
};

@interface CMFileProtection : NSObject

+ (BOOL)apply:(CMProtectionClass)klass toURL:(NSURL *)url error:(NSError **)error;
+ (NSFileProtectionType)foundationValue:(CMProtectionClass)klass;

@end

NS_ASSUME_NONNULL_END
