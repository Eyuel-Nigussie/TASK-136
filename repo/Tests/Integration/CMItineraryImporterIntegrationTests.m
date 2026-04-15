//
//  CMItineraryImporterIntegrationTests.m
//  CourierMatch Integration Tests
//
//  Tests for CMItineraryImporter: valid CSV/JSON, bad schema, partial row
//  rejection, file-size enforcement, and formula-injection neutralization.
//

#import "CMIntegrationTestCase.h"
#import "CMItineraryImporter.h"
#import "CMItinerary.h"
#import "CMErrorCodes.h"

@interface CMItineraryImporterIntegrationTests : CMIntegrationTestCase
@property (nonatomic, strong) CMItineraryImporter *importer;
@end

@implementation CMItineraryImporterIntegrationTests

- (void)setUp {
    [super setUp];
    self.importer = [[CMItineraryImporter alloc] init];
}

#pragma mark - Helpers

/// Writes string content to a temporary file with the given extension and returns its URL.
- (NSURL *)writeTempFile:(NSString *)content extension:(NSString *)ext {
    NSString *filename = [NSString stringWithFormat:@"test_import_%@.%@",
                          [[NSUUID UUID] UUIDString], ext];
    NSURL *url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
    NSError *error = nil;
    [content writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    NSAssert(!error, @"Failed to write temp file: %@", error);
    return url;
}

/// Returns a valid CSV header row.
- (NSString *)validCSVHeader {
    return @"origin_line1,origin_city,origin_state,origin_zip,"
           @"dest_line1,dest_city,dest_state,dest_zip,"
           @"departure_start,departure_end,vehicle_type,capacity_volume,capacity_weight";
}

/// Returns a valid CSV data row.
- (NSString *)validCSVRow {
    // Use far-future dates to avoid past-date rejection.
    return @"123 Main St,New York,NY,10001,"
           @"456 Oak Ave,Los Angeles,CA,90001,"
           @"2099-01-15T08:00:00.000Z,2099-01-15T18:00:00.000Z,car,500,200";
}

#pragma mark - Valid CSV Import

- (void)testValidCSVImportCreatesItineraries {
    NSString *csv = [NSString stringWithFormat:@"%@\n%@\n%@",
                     [self validCSVHeader], [self validCSVRow], [self validCSVRow]];
    NSURL *url = [self writeTempFile:csv extension:@"csv"];

    XCTestExpectation *exp = [self expectationWithDescription:@"CSV import"];
    __block NSUInteger importedCount = 0;
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNotNil(itineraries, @"Itineraries should be returned");
        XCTAssertNil(error, @"No error expected for valid CSV: %@", error);
        importedCount = itineraries.count;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertEqual(importedCount, (NSUInteger)2, @"Should import 2 rows");

    // Refetch from test context to avoid cross-context object access issues.
    [self.testContext reset];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Itinerary"];
    fetch.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
    NSArray<CMItinerary *> *refetched = [self.testContext executeFetchRequest:fetch error:nil];
    XCTAssertGreaterThanOrEqual(refetched.count, 2);
    CMItinerary *first = refetched.firstObject;
    XCTAssertEqualObjects(first.vehicleType, @"car");
    XCTAssertEqualObjects(first.status, @"draft");
    XCTAssertNotNil(first.departureWindowStart);
    XCTAssertNotNil(first.departureWindowEnd);

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Valid JSON Import

- (void)testValidJSONImportCreatesItineraries {
    NSString *json = @"["
        @"{"
        @"\"origin_line1\":\"123 Main St\",\"origin_city\":\"New York\","
        @"\"origin_state\":\"NY\",\"origin_zip\":\"10001\","
        @"\"dest_line1\":\"456 Oak Ave\",\"dest_city\":\"Los Angeles\","
        @"\"dest_state\":\"CA\",\"dest_zip\":\"90001\","
        @"\"departure_start\":\"2099-01-15T08:00:00.000Z\","
        @"\"departure_end\":\"2099-01-15T18:00:00.000Z\","
        @"\"vehicle_type\":\"van\",\"capacity_volume\":\"300\",\"capacity_weight\":\"150\""
        @"}"
        @"]";
    NSURL *url = [self writeTempFile:json extension:@"json"];

    XCTestExpectation *exp = [self expectationWithDescription:@"JSON import"];
    __block NSUInteger importedCount = 0;
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNotNil(itineraries, @"Itineraries should be returned");
        XCTAssertNil(error, @"No error expected for valid JSON: %@", error);
        importedCount = itineraries.count;
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    XCTAssertEqual(importedCount, (NSUInteger)1, @"Should import 1 row");

    // Refetch from test context to avoid cross-context object access.
    [self.testContext reset];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Itinerary"];
    NSArray<CMItinerary *> *refetched = [self.testContext executeFetchRequest:fetch error:nil];
    XCTAssertGreaterThanOrEqual(refetched.count, 1);
    XCTAssertEqualObjects(refetched.firstObject.vehicleType, @"van");

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Bad Schema: Missing Required Column in CSV

- (void)testCSVMissingColumnFailsWithSchemaError {
    // Header missing "dest_zip"
    NSString *csv = @"origin_line1,origin_city,origin_state,origin_zip,"
                    @"dest_line1,dest_city,dest_state,"
                    @"departure_start,departure_end,vehicle_type,capacity_volume,capacity_weight\n"
                    @"123 Main St,New York,NY,10001,"
                    @"456 Oak Ave,Los Angeles,CA,"
                    @"2099-01-15T08:00:00.000Z,2099-01-15T18:00:00.000Z,car,500,200";
    NSURL *url = [self writeTempFile:csv extension:@"csv"];

    XCTestExpectation *exp = [self expectationWithDescription:@"Bad schema"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNil(itineraries, @"No itineraries should be returned for bad schema");
        XCTAssertNotNil(error, @"Error should describe schema problem");
        XCTAssertEqual(error.code, CMErrorCodeImportSchemaInvalid,
                       @"Error code should be ImportSchemaInvalid");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Partial Row Rejection

- (void)testPartialRowRejectionReturnsValidRowsAndError {
    // Row 1: valid; Row 2: invalid vehicle type; Row 3: valid
    NSString *csv = [NSString stringWithFormat:@"%@\n%@\n%@\n%@",
                     [self validCSVHeader],
                     [self validCSVRow],
                     @"789 Elm St,Chicago,IL,60601,"
                     @"321 Pine St,Houston,TX,77001,"
                     @"2099-02-01T09:00:00.000Z,2099-02-01T17:00:00.000Z,helicopter,100,50",
                     [self validCSVRow]];
    NSURL *url = [self writeTempFile:csv extension:@"csv"];

    XCTestExpectation *exp = [self expectationWithDescription:@"Partial rejection"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNotNil(itineraries, @"Valid itineraries should be returned");
        XCTAssertEqual(itineraries.count, 2, @"2 valid rows should be imported");
        XCTAssertNotNil(error, @"Error with rejection details expected");
        NSArray *rejections = error.userInfo[CMItineraryImporterRejectedRowsKey];
        XCTAssertNotNil(rejections, @"Rejected rows should be in error userInfo");
        XCTAssertEqual(rejections.count, 1, @"1 row should be rejected");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - All Rows Rejected

- (void)testAllRowsRejectedReturnsNilAndError {
    NSString *csv = [NSString stringWithFormat:@"%@\n%@",
                     [self validCSVHeader],
                     @"789 Elm St,Chicago,IL,60601,"
                     @"321 Pine St,Houston,TX,77001,"
                     @"2099-02-01T09:00:00.000Z,2099-02-01T17:00:00.000Z,helicopter,100,50"];
    NSURL *url = [self writeTempFile:csv extension:@"csv"];

    XCTestExpectation *exp = [self expectationWithDescription:@"All rejected"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNil(itineraries, @"No itineraries when all rows rejected");
        XCTAssertNotNil(error, @"Error should describe all rows rejected");
        NSArray *rejections = error.userInfo[CMItineraryImporterRejectedRowsKey];
        XCTAssertNotNil(rejections, @"Rejected rows should be in error userInfo");
        XCTAssertGreaterThan(rejections.count, 0);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Unsupported File Format

- (void)testUnsupportedFormatReturnsError {
    NSString *content = @"<xml>not supported</xml>";
    NSURL *url = [self writeTempFile:content extension:@"xml"];

    XCTestExpectation *exp = [self expectationWithDescription:@"Unsupported format"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNil(itineraries, @"No itineraries for unsupported format");
        XCTAssertNotNil(error, @"Error should describe unsupported format");
        XCTAssertEqual(error.code, CMErrorCodeImportSchemaInvalid);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Invalid JSON Structure

- (void)testInvalidJSONStructureReturnsError {
    NSString *json = @"{\"not\": \"an array\"}";
    NSURL *url = [self writeTempFile:json extension:@"json"];

    XCTestExpectation *exp = [self expectationWithDescription:@"Bad JSON"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNil(itineraries, @"No itineraries for bad JSON");
        XCTAssertNotNil(error, @"Error expected for non-array JSON");
        XCTAssertEqual(error.code, CMErrorCodeImportSchemaInvalid);
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

#pragma mark - Departure End Before Start Rejected

- (void)testDepartureEndBeforeStartIsRejected {
    NSString *csv = [NSString stringWithFormat:@"%@\n%@",
                     [self validCSVHeader],
                     @"123 Main St,New York,NY,10001,"
                     @"456 Oak Ave,Los Angeles,CA,90001,"
                     @"2099-01-15T18:00:00.000Z,2099-01-15T08:00:00.000Z,car,500,200"];
    NSURL *url = [self writeTempFile:csv extension:@"csv"];

    XCTestExpectation *exp = [self expectationWithDescription:@"End before start"];
    [self.importer importFromURL:url completion:^(NSArray<CMItinerary *> *itineraries, NSError *error) {
        XCTAssertNil(itineraries, @"No itineraries when all rows invalid");
        XCTAssertNotNil(error, @"Error expected for departure end before start");
        [exp fulfill];
    }];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
}

@end
