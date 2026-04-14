//
//  CMAttachmentAllowlistTests.m
//  CourierMatch Tests
//
//  Tests for attachment validation: MIME allowlist, file size limits,
//  and magic byte verification.
//

#import <XCTest/XCTest.h>
#import "CMAttachmentAllowlist.h"
#import "CMErrorCodes.h"

@interface CMAttachmentAllowlistTests : XCTestCase
@property (nonatomic, strong) CMAttachmentAllowlist *allowlist;
@end

@implementation CMAttachmentAllowlistTests

- (void)setUp {
    [super setUp];
    // Create a fresh instance for each test to avoid shared singleton state.
    self.allowlist = [[CMAttachmentAllowlist alloc] init];
}

#pragma mark - Helpers

/// Creates test data with JPEG magic bytes (FF D8 FF) followed by padding.
- (NSData *)jpegDataWithSize:(NSUInteger)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    uint8_t *bytes = data.mutableBytes;
    bytes[0] = 0xFF;
    bytes[1] = 0xD8;
    bytes[2] = 0xFF;
    bytes[3] = 0xE0;
    return data;
}

/// Creates test data with PNG magic bytes (89 50 4E 47) followed by padding.
- (NSData *)pngDataWithSize:(NSUInteger)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    uint8_t *bytes = data.mutableBytes;
    bytes[0] = 0x89;
    bytes[1] = 0x50;
    bytes[2] = 0x4E;
    bytes[3] = 0x47;
    return data;
}

/// Creates test data with PDF magic bytes (%PDF = 25 50 44 46) followed by padding.
- (NSData *)pdfDataWithSize:(NSUInteger)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    uint8_t *bytes = data.mutableBytes;
    bytes[0] = 0x25; // %
    bytes[1] = 0x50; // P
    bytes[2] = 0x44; // D
    bytes[3] = 0x46; // F
    return data;
}

/// Creates data with no valid magic bytes.
- (NSData *)garbageDataWithSize:(NSUInteger)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    uint8_t *bytes = data.mutableBytes;
    bytes[0] = 0x00;
    bytes[1] = 0x00;
    bytes[2] = 0x00;
    bytes[3] = 0x00;
    return data;
}

#pragma mark - MIME Allowlist: image/jpeg Allowed, image/gif Rejected

- (void)testImageJPEGAllowed {
    NSData *data = [self jpegDataWithSize:1024];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/jpeg" error:&error];
    XCTAssertTrue(valid, @"image/jpeg should be allowed");
    XCTAssertNil(error);
}

- (void)testImageGIFRejected {
    // GIF magic bytes: GIF89a
    NSMutableData *data = [NSMutableData dataWithLength:1024];
    uint8_t *bytes = data.mutableBytes;
    bytes[0] = 0x47; // G
    bytes[1] = 0x49; // I
    bytes[2] = 0x46; // F
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/gif" error:&error];
    XCTAssertFalse(valid, @"image/gif should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeAttachmentMimeNotAllowed);
}

#pragma mark - image/png Allowed

- (void)testImagePNGAllowed {
    NSData *data = [self pngDataWithSize:1024];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/png" error:&error];
    XCTAssertTrue(valid, @"image/png should be allowed");
    XCTAssertNil(error);
}

#pragma mark - application/pdf Allowed

- (void)testApplicationPDFAllowed {
    NSData *data = [self pdfDataWithSize:1024];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"application/pdf" error:&error];
    XCTAssertTrue(valid, @"application/pdf should be allowed");
    XCTAssertNil(error);
}

#pragma mark - 10 MB Passes, 10.1 MB Rejected

- (void)testExactly10MBPasses {
    NSUInteger tenMB = 10 * 1024 * 1024;
    NSData *data = [self jpegDataWithSize:tenMB];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/jpeg" error:&error];
    XCTAssertTrue(valid, @"Exactly 10 MB file should pass size validation");
    XCTAssertNil(error);
}

- (void)testSlightlyOver10MBRejected {
    // 10 MB + ~100 KB = 10,585,088 bytes (over 10,485,760)
    NSUInteger overSize = (10 * 1024 * 1024) + (100 * 1024);
    NSData *data = [self jpegDataWithSize:overSize];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/jpeg" error:&error];
    XCTAssertFalse(valid, @"10.1 MB file should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeAttachmentTooLarge,
        @"Error code should be CMErrorCodeAttachmentTooLarge");
}

#pragma mark - JPEG Magic Bytes + mimeType "image/jpeg" -> Passes

- (void)testJPEGMagicBytesMatchJPEGMime {
    NSData *data = [self jpegDataWithSize:512];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/jpeg" error:&error];
    XCTAssertTrue(valid, @"JPEG magic + image/jpeg MIME should pass");
    XCTAssertNil(error);
}

#pragma mark - PNG Magic Bytes + mimeType "image/png" -> Passes

- (void)testPNGMagicBytesMatchPNGMime {
    NSData *data = [self pngDataWithSize:512];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/png" error:&error];
    XCTAssertTrue(valid, @"PNG magic + image/png MIME should pass");
    XCTAssertNil(error);
}

#pragma mark - PDF Magic Bytes + mimeType "application/pdf" -> Passes

- (void)testPDFMagicBytesMatchPDFMime {
    NSData *data = [self pdfDataWithSize:512];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"application/pdf" error:&error];
    XCTAssertTrue(valid, @"PDF magic + application/pdf MIME should pass");
    XCTAssertNil(error);
}

#pragma mark - JPEG Magic Bytes + mimeType "image/png" -> Rejected (Magic Mismatch)

- (void)testJPEGMagicWithPNGMimeRejected {
    NSData *data = [self jpegDataWithSize:512];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/png" error:&error];
    XCTAssertFalse(valid, @"JPEG magic + image/png MIME should be rejected as magic mismatch");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeAttachmentMagicMismatch,
        @"Error code should be CMErrorCodeAttachmentMagicMismatch");
}

#pragma mark - No Magic Bytes at All -> Rejected

- (void)testNoMagicBytesRejected {
    NSData *data = [self garbageDataWithSize:512];
    NSError *error = nil;
    BOOL valid = [self.allowlist validateData:data declaredMIME:@"image/jpeg" error:&error];
    XCTAssertFalse(valid, @"Data with no valid magic bytes should be rejected");
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, CMErrorCodeAttachmentMagicMismatch,
        @"Error code should be CMErrorCodeAttachmentMagicMismatch for unrecognized bytes");
}

@end
