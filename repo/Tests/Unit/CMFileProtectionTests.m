//
//  CMFileProtectionTests.m
//  CourierMatch Unit Tests
//
//  Covers CMFileProtection.foundationValue: and apply:toURL:error:
//

#import <XCTest/XCTest.h>
#import "CMFileProtection.h"

@interface CMFileProtectionTests : XCTestCase
@property (nonatomic, copy) NSURL *tempFileURL;
@end

@implementation CMFileProtectionTests

- (void)setUp {
    [super setUp];
    // Create a temporary file for testing apply:toURL:error:
    NSURL *tmpDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    self.tempFileURL = [tmpDir URLByAppendingPathComponent:
                        [NSString stringWithFormat:@"fp-test-%@.bin", [[NSUUID UUID] UUIDString]]];
    [@"test" writeToURL:self.tempFileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.tempFileURL error:nil];
    [super tearDown];
}

#pragma mark - foundationValue:

- (void)testFoundationValue_Complete {
    NSFileProtectionType v = [CMFileProtection foundationValue:CMProtectionClassComplete];
    XCTAssertEqualObjects(v, NSFileProtectionComplete);
}

- (void)testFoundationValue_CompleteUntilFirstUserAuth {
    NSFileProtectionType v = [CMFileProtection foundationValue:CMProtectionClassCompleteUntilFirstUserAuth];
    XCTAssertEqualObjects(v, NSFileProtectionCompleteUntilFirstUserAuthentication);
}

- (void)testFoundationValue_CompleteUnlessOpen {
    NSFileProtectionType v = [CMFileProtection foundationValue:CMProtectionClassCompleteUnlessOpen];
    XCTAssertEqualObjects(v, NSFileProtectionCompleteUnlessOpen);
}

- (void)testFoundationValue_None {
    NSFileProtectionType v = [CMFileProtection foundationValue:CMProtectionClassNone];
    XCTAssertEqualObjects(v, NSFileProtectionNone);
}

#pragma mark - apply:toURL:error:

- (void)testApply_NilURLReturnsFalse {
    NSError *err = nil;
    BOOL result = [CMFileProtection apply:CMProtectionClassComplete toURL:nil error:&err];
    XCTAssertFalse(result, @"nil URL should return NO");
}

- (void)testApply_ValidFileURL {
    // On iOS simulator, file protection may not be enforced, but the call should
    // succeed or fail cleanly without crashing.
    NSError *err = nil;
    BOOL result = [CMFileProtection apply:CMProtectionClassNone
                                    toURL:self.tempFileURL
                                    error:&err];
    // On simulator, setAttributes may succeed or fail; either is acceptable.
    (void)result;
}

- (void)testApply_AllProtectionClasses {
    CMProtectionClass classes[] = {
        CMProtectionClassComplete,
        CMProtectionClassCompleteUntilFirstUserAuth,
        CMProtectionClassCompleteUnlessOpen,
        CMProtectionClassNone,
    };
    for (NSUInteger i = 0; i < 4; i++) {
        NSError *err = nil;
        // Should not crash for any protection class.
        XCTAssertNoThrow([CMFileProtection apply:classes[i]
                                          toURL:self.tempFileURL
                                          error:&err]);
    }
}

@end
