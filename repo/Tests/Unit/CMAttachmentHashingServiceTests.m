//
//  CMAttachmentHashingServiceTests.m
//  CourierMatch Tests
//

#import <XCTest/XCTest.h>
#import "CMAttachmentHashingService.h"

@interface CMAttachmentHashingServiceTests : XCTestCase
@property (nonatomic, strong) NSURL *tempDir;
@end

@implementation CMAttachmentHashingServiceTests

- (void)setUp {
    [super setUp];
    self.tempDir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                                            [[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.tempDir
                             withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtURL:self.tempDir error:nil];
    [super tearDown];
}

- (NSURL *)writeFileWithContent:(NSString *)content {
    NSURL *url = [self.tempDir URLByAppendingPathComponent:@"test.txt"];
    [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return url;
}

- (void)testSharedReturnsSingleton {
    CMAttachmentHashingService *a = [CMAttachmentHashingService shared];
    CMAttachmentHashingService *b = [CMAttachmentHashingService shared];
    XCTAssertEqual(a, b);
}

- (void)testHashFileProducesDeterministicResult {
    NSURL *url = [self writeFileWithContent:@"hello world"];

    XCTestExpectation *exp1 = [self expectationWithDescription:@"hash1"];
    XCTestExpectation *exp2 = [self expectationWithDescription:@"hash2"];
    __block NSString *hash1, *hash2;

    [[CMAttachmentHashingService shared] hashFileAtURL:url completion:^(NSString *h, NSError *e) {
        hash1 = h; [exp1 fulfill];
    }];
    [[CMAttachmentHashingService shared] hashFileAtURL:url completion:^(NSString *h, NSError *e) {
        hash2 = h; [exp2 fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertNotNil(hash1);
    XCTAssertNotNil(hash2);
    XCTAssertEqualObjects(hash1, hash2, @"Same content should produce same hash");
    // SHA-256 hex is 64 chars
    XCTAssertEqual(hash1.length, (NSUInteger)64);
}

- (void)testHashFileDifferentContentDifferentHash {
    NSURL *u1 = [self.tempDir URLByAppendingPathComponent:@"a.txt"];
    NSURL *u2 = [self.tempDir URLByAppendingPathComponent:@"b.txt"];
    [@"foo" writeToURL:u1 atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"bar" writeToURL:u2 atomically:YES encoding:NSUTF8StringEncoding error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"two hashes"];
    __block NSString *h1, *h2;
    [[CMAttachmentHashingService shared] hashFileAtURL:u1 completion:^(NSString *h, NSError *e) {
        h1 = h;
        [[CMAttachmentHashingService shared] hashFileAtURL:u2 completion:^(NSString *h2_, NSError *e2) {
            h2 = h2_;
            [exp fulfill];
        }];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertNotNil(h1);
    XCTAssertNotNil(h2);
    XCTAssertNotEqualObjects(h1, h2);
}

- (void)testHashFileMissingReturnsError {
    NSURL *missing = [self.tempDir URLByAppendingPathComponent:@"does-not-exist.txt"];
    XCTestExpectation *exp = [self expectationWithDescription:@"missing"];
    __block NSError *err;
    __block NSString *hash;
    [[CMAttachmentHashingService shared] hashFileAtURL:missing completion:^(NSString *h, NSError *e) {
        hash = h; err = e; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertNil(hash);
    XCTAssertNotNil(err);
}

- (void)testCancelAllDoesNotCrash {
    XCTAssertNoThrow([[CMAttachmentHashingService shared] cancelAll]);
}

- (void)testHashLargeFile {
    // 1MB file
    NSMutableData *data = [NSMutableData dataWithLength:1024 * 1024];
    NSURL *url = [self.tempDir URLByAppendingPathComponent:@"large.bin"];
    [data writeToURL:url atomically:YES];

    XCTestExpectation *exp = [self expectationWithDescription:@"large"];
    __block NSString *hash;
    [[CMAttachmentHashingService shared] hashFileAtURL:url completion:^(NSString *h, NSError *e) {
        hash = h; [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertNotNil(hash);
    XCTAssertEqual(hash.length, (NSUInteger)64);
}

@end
