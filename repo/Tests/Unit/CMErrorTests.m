//
//  CMErrorTests.m
//  CourierMatch Unit Tests
//
//  Covers the CMError factory: all three creation methods, domain/code
//  propagation, message → NSLocalizedDescriptionKey, and underlying error.
//

#import <XCTest/XCTest.h>
#import "CMError.h"
#import "CMErrorCodes.h"

@interface CMErrorTests : XCTestCase
@end

@implementation CMErrorTests

#pragma mark - errorWithCode:message:

- (void)testErrorWithCode_HasCorrectDomain {
    NSError *err = [CMError errorWithCode:CMErrorCodeUnknown message:@"test"];
    XCTAssertEqualObjects(err.domain, CMErrorDomain);
}

- (void)testErrorWithCode_HasCorrectCode {
    NSError *err = [CMError errorWithCode:CMErrorCodeValidationFailed message:@"msg"];
    XCTAssertEqual(err.code, CMErrorCodeValidationFailed);
}

- (void)testErrorWithCode_MessageAppearsInLocalizedDescription {
    NSError *err = [CMError errorWithCode:CMErrorCodePermissionDenied message:@"access denied"];
    XCTAssertEqualObjects(err.userInfo[NSLocalizedDescriptionKey], @"access denied");
}

- (void)testErrorWithCode_NilMessage_NoDescriptionKey {
    NSError *err = [CMError errorWithCode:CMErrorCodeUnknown message:nil];
    XCTAssertNil(err.userInfo[NSLocalizedDescriptionKey],
                 @"Nil message must not set NSLocalizedDescriptionKey");
}

#pragma mark - errorWithCode:message:userInfo:

- (void)testErrorWithCodeMessageUserInfo_MergesUserInfo {
    NSDictionary *extra = @{@"detail": @"extra field"};
    NSError *err = [CMError errorWithCode:CMErrorCodeValidationFailed
                                  message:@"bad input"
                                 userInfo:extra];
    XCTAssertEqualObjects(err.userInfo[@"detail"], @"extra field");
    XCTAssertEqualObjects(err.userInfo[NSLocalizedDescriptionKey], @"bad input");
}

- (void)testErrorWithCodeMessageUserInfo_NilUserInfo_DoesNotCrash {
    XCTAssertNoThrow([CMError errorWithCode:CMErrorCodeUnknown message:@"msg" userInfo:nil]);
}

- (void)testErrorWithCodeMessageUserInfo_HasCorrectCode {
    NSError *err = [CMError errorWithCode:CMErrorCodeCoreDataSaveFailed
                                  message:@"save failed"
                                 userInfo:nil];
    XCTAssertEqual(err.code, CMErrorCodeCoreDataSaveFailed);
}

#pragma mark - errorWithCode:message:underlyingError:

- (void)testErrorWithCodeMessageUnderlyingError_PropagatesUnderlying {
    NSError *underlying = [NSError errorWithDomain:NSCocoaErrorDomain code:256 userInfo:nil];
    NSError *err = [CMError errorWithCode:CMErrorCodeAuditWriteFailed
                                  message:@"write failed"
                          underlyingError:underlying];
    XCTAssertEqual(err.userInfo[NSUnderlyingErrorKey], underlying);
}

- (void)testErrorWithCodeMessageUnderlyingError_NilUnderlying_NoUnderlyingKey {
    NSError *err = [CMError errorWithCode:CMErrorCodeAuditWriteFailed
                                  message:@"write failed"
                          underlyingError:nil];
    XCTAssertNil(err.userInfo[NSUnderlyingErrorKey],
                 @"Nil underlying error must not set NSUnderlyingErrorKey");
}

- (void)testErrorWithCodeMessageUnderlyingError_HasCorrectDomain {
    NSError *err = [CMError errorWithCode:CMErrorCodeAuditChainBroken
                                  message:@"chain broken"
                          underlyingError:nil];
    XCTAssertEqualObjects(err.domain, CMErrorDomain);
}

#pragma mark - Representative Error Codes

- (void)testAuthErrorCodeIsInCorrectRange {
    NSError *err = [CMError errorWithCode:CMErrorCodeAuthInvalidCredentials message:nil];
    XCTAssertTrue(err.code >= 2000 && err.code < 3000,
                  @"Auth error codes must be in the 2xxx range");
}

- (void)testPersistenceErrorCodeIsInCorrectRange {
    NSError *err = [CMError errorWithCode:CMErrorCodeCoreDataBootFailed message:nil];
    XCTAssertTrue(err.code >= 1000 && err.code < 2000,
                  @"Persistence error codes must be in the 1xxx range");
}

@end
