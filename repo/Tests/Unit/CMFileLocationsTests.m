//
//  CMFileLocationsTests.m
//  CourierMatch Tests
//
//  Tests for attachment directory path behavior with various tenant ID formats.
//

#import <XCTest/XCTest.h>
#import "CMFileLocations.h"

@interface CMFileLocationsTests : XCTestCase
@end

@implementation CMFileLocationsTests

#pragma mark - sanitizedPathComponent

- (void)testSanitizedPathComponent_UUID_Accepted {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"550e8400-e29b-41d4-a716-446655440000"];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, @"550e8400-e29b-41d4-a716-446655440000");
}

- (void)testSanitizedPathComponent_AlphanumericSlug_Accepted {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"test-tenant-001"];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, @"test-tenant-001");
}

- (void)testSanitizedPathComponent_NumericOnly_Accepted {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"12345"];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, @"12345");
}

- (void)testSanitizedPathComponent_Empty_ReturnsNil {
    XCTAssertNil([CMFileLocations sanitizedPathComponent:@""]);
}

- (void)testSanitizedPathComponent_Nil_ReturnsNil {
    XCTAssertNil([CMFileLocations sanitizedPathComponent:nil]);
}

- (void)testSanitizedPathComponent_PathTraversal_Stripped {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"../../etc/passwd"];
    XCTAssertNotNil(result);
    // Only alphanumeric + hyphen + underscore survive; dots and slashes are stripped.
    XCTAssertFalse([result containsString:@".."], @"Path traversal dots should be stripped");
    XCTAssertFalse([result containsString:@"/"], @"Slashes should be stripped");
}

- (void)testSanitizedPathComponent_SpecialChars_Stripped {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"tenant@#$%^&*()!"];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result, @"tenant");
}

- (void)testSanitizedPathComponent_AllSpecialChars_ReturnsNil {
    NSString *result = [CMFileLocations sanitizedPathComponent:@"@#$%^&*()!"];
    XCTAssertNil(result, @"All-special-chars string should return nil");
}

#pragma mark - attachmentsDirectoryForTenantId

- (void)testAttachmentsDirectory_UUID_ReturnsNonNil {
    NSURL *url = [CMFileLocations attachmentsDirectoryForTenantId:@"550e8400-e29b-41d4-a716-446655440000"
                                                  createIfNeeded:NO];
    XCTAssertNotNil(url, @"UUID tenant ID should produce a valid directory URL");
    XCTAssertTrue([url.path containsString:@"attachments"], @"Path should contain 'attachments'");
}

- (void)testAttachmentsDirectory_NonUUIDSlug_ReturnsNonNil {
    NSURL *url = [CMFileLocations attachmentsDirectoryForTenantId:@"test-tenant-001"
                                                  createIfNeeded:NO];
    XCTAssertNotNil(url, @"Non-UUID alphanumeric tenant ID should produce a valid directory URL");
    XCTAssertTrue([url.path containsString:@"test-tenant-001"]);
}

- (void)testAttachmentsDirectory_Empty_ReturnsNil {
    NSURL *url = [CMFileLocations attachmentsDirectoryForTenantId:@""
                                                  createIfNeeded:NO];
    XCTAssertNil(url, @"Empty tenant ID should return nil");
}

- (void)testAttachmentsDirectory_PathTraversal_Sanitized {
    NSURL *url = [CMFileLocations attachmentsDirectoryForTenantId:@"../../secret"
                                                  createIfNeeded:NO];
    XCTAssertNotNil(url, @"Path-traversal tenant ID should be sanitized, not rejected");
    XCTAssertFalse([url.path containsString:@".."], @"Sanitized path should not contain traversal");
}

@end
