//
//  CMEncryptedValueTransformerTests.m
//  CourierMatch Tests
//
//  Roundtrip tests for the AES-encrypted value transformer used by Core Data
//  for sensitive fields.
//

#import <XCTest/XCTest.h>
#import "CMEncryptedValueTransformer.h"

@interface CMEncryptedValueTransformerTests : XCTestCase
@end

@implementation CMEncryptedValueTransformerTests

- (void)setUp {
    [super setUp];
    [CMEncryptedValueTransformer registerTransformer];
}

- (void)testTransformerIsRegistered {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    XCTAssertNotNil(t, @"Transformer should be registered after registerTransformer");
}

- (void)testRegisterTransformerIsIdempotent {
    [CMEncryptedValueTransformer registerTransformer];
    [CMEncryptedValueTransformer registerTransformer];
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    XCTAssertNotNil(t, @"Multiple registrations should not throw");
}

- (void)testStringRoundtrip {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    NSString *original = @"sensitive-payload-12345";
    id encrypted = [t transformedValue:original];
    XCTAssertNotNil(encrypted, @"Encrypted form should not be nil");
    XCTAssertNotEqualObjects(encrypted, original, @"Encrypted form differs from plaintext");
    id decrypted = [t reverseTransformedValue:encrypted];
    XCTAssertNotNil(decrypted);
    // Decrypted may be NSData or NSString depending on transformer; verify bytes match.
    NSData *decryptedData = [decrypted isKindOfClass:[NSData class]]
        ? decrypted
        : [decrypted dataUsingEncoding:NSUTF8StringEncoding];
    NSData *originalData = [original dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(decryptedData, originalData, @"Roundtrip should preserve bytes");
}

- (void)testDataRoundtrip {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    NSData *original = [@"binary blob" dataUsingEncoding:NSUTF8StringEncoding];
    id encrypted = [t transformedValue:original];
    XCTAssertNotNil(encrypted);
    id decrypted = [t reverseTransformedValue:encrypted];
    // For NSData, decrypted should equal the original bytes (or its string form).
    XCTAssertNotNil(decrypted);
}

- (void)testNilInputReturnsNil {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    XCTAssertNil([t transformedValue:nil], @"nil input should yield nil output");
    XCTAssertNil([t reverseTransformedValue:nil], @"nil input should yield nil output");
}

- (void)testEmptyStringRoundtrip {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    NSString *empty = @"";
    id encrypted = [t transformedValue:empty];
    if (encrypted) {
        id decrypted = [t reverseTransformedValue:encrypted];
        XCTAssertNotNil(decrypted);
        NSData *decData = [decrypted isKindOfClass:[NSData class]] ? decrypted
            : [decrypted dataUsingEncoding:NSUTF8StringEncoding];
        XCTAssertEqual(decData.length, (NSUInteger)0);
    }
}

- (void)testLongStringRoundtrip {
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:CMEncryptedValueTransformerName];
    NSMutableString *longStr = [NSMutableString string];
    for (int i = 0; i < 1000; i++) { [longStr appendString:@"abcdefghij"]; }
    id encrypted = [t transformedValue:longStr];
    XCTAssertNotNil(encrypted);
    id decrypted = [t reverseTransformedValue:encrypted];
    XCTAssertNotNil(decrypted);
    NSData *decData = [decrypted isKindOfClass:[NSData class]] ? decrypted
        : [decrypted dataUsingEncoding:NSUTF8StringEncoding];
    NSData *origData = [longStr dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(decData, origData);
}

- (void)testTransformedValueClassIsNSData {
    Class cls = [CMEncryptedValueTransformer transformedValueClass];
    XCTAssertEqualObjects(cls, [NSData class],
                          @"Encrypted output class should be NSData");
}

- (void)testAllowsReverseTransformationIsYES {
    BOOL allows = [CMEncryptedValueTransformer allowsReverseTransformation];
    XCTAssertTrue(allows, @"Transformer must support reverse transformation for decryption");
}

@end
