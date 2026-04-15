//
//  CMAttachmentServiceTests.m
//  CourierMatch Integration Tests
//

#import "CMIntegrationTestCase.h"
#import "CMAttachmentService.h"
#import "CMAttachment.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"

// 1x1 PNG (89 50 4E 47 0D 0A 1A 0A header + minimal IDAT)
static NSData *MinimalPNG(void) {
    static const uint8_t bytes[] = {
        0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,  // PNG header
        0x00,0x00,0x00,0x0D,0x49,0x48,0x44,0x52,
        0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x01,
        0x08,0x06,0x00,0x00,0x00,0x1F,0x15,0xC4,
        0x89,0x00,0x00,0x00,0x0D,0x49,0x44,0x41,
        0x54,0x78,0x9C,0x62,0x00,0x01,0x00,0x00,
        0x05,0x00,0x01,0x0D,0x0A,0x2D,0xB4,0x00,
        0x00,0x00,0x00,0x49,0x45,0x4E,0x44,0xAE,
        0x42,0x60,0x82
    };
    return [NSData dataWithBytes:bytes length:sizeof(bytes)];
}

// JPEG header (FF D8 FF)
static NSData *MinimalJPEG(void) {
    NSMutableData *d = [NSMutableData data];
    uint8_t header[] = {0xFF,0xD8,0xFF,0xE0,0x00,0x10,0x4A,0x46,0x49,0x46,0x00};
    [d appendBytes:header length:sizeof(header)];
    // pad to 200 bytes for "data"
    uint8_t pad[200] = {0};
    [d appendBytes:pad length:sizeof(pad)];
    uint8_t footer[] = {0xFF,0xD9};
    [d appendBytes:footer length:sizeof(footer)];
    return d;
}

@interface CMAttachmentServiceTests : CMIntegrationTestCase
@end

@implementation CMAttachmentServiceTests

- (void)setUp {
    [super setUp];
    // Open a session so attachment service preflight passes.
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
}

- (void)testSharedReturnsSingleton {
    XCTAssertEqual([CMAttachmentService shared], [CMAttachmentService shared]);
}

- (void)testSavePNGAttachment {
    [self switchToUser:self.courierUser];
    XCTestExpectation *exp = [self expectationWithDescription:@"Save PNG"];
    __block CMAttachment *saved;
    __block NSError *err;
    [[CMAttachmentService shared] saveAttachmentWithFilename:@"photo.png"
                                                        data:MinimalPNG()
                                                    mimeType:@"image/png"
                                                   ownerType:@"Order"
                                                     ownerId:@"order-att-1"
                                                  completion:^(CMAttachment *a, NSError *e) {
        saved = a; err = e; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(saved, @"Save should succeed: %@", err);
    XCTAssertNil(err);
    // Object lives on a background context — properties may need refresh.
    // We only assert the object was created; specific field checks can vary.
}

- (void)testSaveJPEGAttachment {
    [self switchToUser:self.courierUser];
    XCTestExpectation *exp = [self expectationWithDescription:@"Save JPEG"];
    __block CMAttachment *saved;
    [[CMAttachmentService shared] saveAttachmentWithFilename:@"photo.jpg"
                                                        data:MinimalJPEG()
                                                    mimeType:@"image/jpeg"
                                                   ownerType:@"Order"
                                                     ownerId:@"order-att-2"
                                                  completion:^(CMAttachment *a, NSError *e) {
        saved = a; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(saved);
}

- (void)testSaveRejectsBadMime {
    [self switchToUser:self.courierUser];
    XCTestExpectation *exp = [self expectationWithDescription:@"Reject bad mime"];
    __block NSError *err;
    __block CMAttachment *saved;
    [[CMAttachmentService shared] saveAttachmentWithFilename:@"bad.exe"
                                                        data:MinimalPNG()
                                                    mimeType:@"application/x-executable"
                                                   ownerType:@"Order"
                                                     ownerId:@"order-att-3"
                                                  completion:^(CMAttachment *a, NSError *e) {
        saved = a; err = e; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil(saved);
    XCTAssertNotNil(err);
}

- (void)testSaveRejectsTooLarge {
    [self switchToUser:self.courierUser];
    NSMutableData *huge = [NSMutableData dataWithLength:11 * 1024 * 1024]; // 11MB
    XCTestExpectation *exp = [self expectationWithDescription:@"Reject too large"];
    __block NSError *err;
    __block CMAttachment *saved;
    [[CMAttachmentService shared] saveAttachmentWithFilename:@"huge.png"
                                                        data:huge
                                                    mimeType:@"image/png"
                                                   ownerType:@"Order"
                                                     ownerId:@"order-att-4"
                                                  completion:^(CMAttachment *a, NSError *e) {
        saved = a; err = e; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNil(saved);
    XCTAssertNotNil(err);
}

- (void)testFlushThumbnailCacheDoesNotCrash {
    XCTAssertNoThrow([[CMAttachmentService shared] flushThumbnailCache]);
}

@end
