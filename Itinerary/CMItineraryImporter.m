//
//  CMItineraryImporter.m
//  CourierMatch
//

#import "CMItineraryImporter.h"
#import "CMItinerary.h"
#import "CMAddress.h"
#import "CMAddressNormalizer.h"
#import "CMItineraryRepository.h"
#import "CMCoreDataStack.h"
#import "CMTenantContext.h"
#import "CMDateFormatters.h"
#import "CMError.h"
#import "CMErrorCodes.h"
#import "NSManagedObjectContext+CMHelpers.h"

NSString * const CMItineraryImporterRejectedRowsKey = @"CMItineraryImporterRejectedRows";

static const NSUInteger kMaxFileSize       = 2 * 1024 * 1024;  // 2 MB
static const NSUInteger kMaxRowCount       = 10000;
static const NSUInteger kMaxFieldLength    = 512;

/// Expected CSV column names (header row).
static NSArray<NSString *> *CMImportExpectedColumns(void) {
    return @[
        @"origin_line1", @"origin_city", @"origin_state", @"origin_zip",
        @"dest_line1", @"dest_city", @"dest_state", @"dest_zip",
        @"departure_start", @"departure_end",
        @"vehicle_type", @"capacity_volume", @"capacity_weight"
    ];
}

#pragma mark - Helper: strip BOM

static NSString *CMStripBOM(NSString *input) {
    if (input.length > 0) {
        unichar first = [input characterAtIndex:0];
        if (first == 0xFEFF || first == 0xFFFE) {
            return [input substringFromIndex:1];
        }
    }
    return input;
}

#pragma mark - Helper: neutralize formula injection

static NSString *CMNeutralizeFormula(NSString *field) {
    if (field.length == 0) return field;
    unichar first = [field characterAtIndex:0];
    if (first == '=' || first == '+' || first == '@' || first == '-') {
        return [NSString stringWithFormat:@"'%@", field];
    }
    return field;
}

#pragma mark - Helper: truncate field

static NSString *CMTruncateField(NSString *field) {
    if (field.length > kMaxFieldLength) {
        return [field substringToIndex:kMaxFieldLength];
    }
    return field;
}

#pragma mark - Helper: sanitize field (truncate + neutralize)

static NSString *CMSanitizeField(NSString *field) {
    NSString *trimmed = [field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    trimmed = CMTruncateField(trimmed);
    trimmed = CMNeutralizeFormula(trimmed);
    return trimmed;
}

#pragma mark - Simple CSV line parser (handles quoted fields)

static NSArray<NSString *> *CMParseCSVLine(NSString *line) {
    NSMutableArray<NSString *> *fields = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    BOOL inQuotes = NO;
    NSUInteger len = line.length;

    for (NSUInteger i = 0; i < len; i++) {
        unichar c = [line characterAtIndex:i];
        if (inQuotes) {
            if (c == '"') {
                // Peek ahead for escaped quote
                if (i + 1 < len && [line characterAtIndex:i + 1] == '"') {
                    [current appendString:@"\""];
                    i++; // skip next quote
                } else {
                    inQuotes = NO;
                }
            } else {
                [current appendFormat:@"%C", c];
            }
        } else {
            if (c == '"') {
                inQuotes = YES;
            } else if (c == ',') {
                [fields addObject:[current copy]];
                current = [NSMutableString string];
            } else {
                [current appendFormat:@"%C", c];
            }
        }
    }
    [fields addObject:[current copy]];
    return fields;
}

@implementation CMItineraryImporter

- (void)importFromURL:(NSURL *)fileURL
           completion:(void (^)(NSArray<CMItinerary *> * _Nullable,
                                NSError * _Nullable))completion {

    // --- File size check ---
    NSNumber *fileSize = nil;
    NSError *attrError = nil;
    [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&attrError];
    if (attrError || !fileSize) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [CMError errorWithCode:CMErrorCodeImportFileTooLarge
                                           message:@"Unable to read file size."]);
        });
        return;
    }
    if (fileSize.unsignedIntegerValue > kMaxFileSize) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [CMError errorWithCode:CMErrorCodeImportFileTooLarge
                                           message:@"File exceeds the 2 MB import limit."]);
        });
        return;
    }

    // --- Read file content ---
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&attrError];
    if (!data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [CMError errorWithCode:CMErrorCodeImportFileTooLarge
                                           message:attrError.localizedDescription ?: @"Cannot read file."]);
        });
        return;
    }

    NSString *raw = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!raw) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                           message:@"File is not valid UTF-8."]);
        });
        return;
    }
    raw = CMStripBOM(raw);

    // --- Detect format ---
    NSString *ext = fileURL.pathExtension.lowercaseString;
    BOOL isJSON = [ext isEqualToString:@"json"];
    BOOL isCSV  = [ext isEqualToString:@"csv"];

    if (!isJSON && !isCSV) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                           message:@"Unsupported file format. Use .csv or .json."]);
        });
        return;
    }

    // --- Parse rows ---
    NSArray<NSDictionary<NSString *, NSString *> *> *rows = nil;
    NSError *parseError = nil;

    if (isJSON) {
        rows = [self parseJSONRows:raw error:&parseError];
    } else {
        rows = [self parseCSVRows:raw error:&parseError];
    }

    if (!rows) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, parseError);
        });
        return;
    }

    if (rows.count > kMaxRowCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = [NSString stringWithFormat:@"File contains %lu rows, exceeding the %lu row limit.",
                             (unsigned long)rows.count, (unsigned long)kMaxRowCount];
            completion(nil, [CMError errorWithCode:CMErrorCodeImportRowCountExceeded message:msg]);
        });
        return;
    }

    if (rows.count == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], nil);
        });
        return;
    }

    // --- Persist on background context ---
    [[CMCoreDataStack shared] performBackgroundTask:^(NSManagedObjectContext *ctx) {
        CMItineraryRepository *repo = [[CMItineraryRepository alloc] initWithContext:ctx];
        CMAddressNormalizer *normalizer = [CMAddressNormalizer shared];
        NSString *courierId = [CMTenantContext shared].currentUserId ?: @"";

        NSMutableArray<CMItinerary *> *created = [NSMutableArray array];
        NSMutableArray<NSString *> *rejections = [NSMutableArray array];

        NSDateFormatter *isoFmt = [CMDateFormatters iso8601UTCFormatter];

        for (NSUInteger i = 0; i < rows.count; i++) {
            NSDictionary<NSString *, NSString *> *row = rows[i];

            // Sanitize all fields
            NSString *origLine1  = CMSanitizeField(row[@"origin_line1"] ?: @"");
            NSString *origCity   = CMSanitizeField(row[@"origin_city"] ?: @"");
            NSString *origState  = CMSanitizeField(row[@"origin_state"] ?: @"");
            NSString *origZip    = CMSanitizeField(row[@"origin_zip"] ?: @"");
            NSString *destLine1  = CMSanitizeField(row[@"dest_line1"] ?: @"");
            NSString *destCity   = CMSanitizeField(row[@"dest_city"] ?: @"");
            NSString *destState  = CMSanitizeField(row[@"dest_state"] ?: @"");
            NSString *destZip    = CMSanitizeField(row[@"dest_zip"] ?: @"");
            NSString *depStart   = CMSanitizeField(row[@"departure_start"] ?: @"");
            NSString *depEnd     = CMSanitizeField(row[@"departure_end"] ?: @"");
            NSString *vType      = CMSanitizeField(row[@"vehicle_type"] ?: @"");
            NSString *volStr     = CMSanitizeField(row[@"capacity_volume"] ?: @"");
            NSString *wgtStr     = CMSanitizeField(row[@"capacity_weight"] ?: @"");

            // Validate origin address
            CMNormalizedAddress *normOrigin = [normalizer normalizeLine1:origLine1
                                                                  line2:nil
                                                                   city:origCity
                                                                  state:origState
                                                                    zip:origZip];
            if (!normOrigin) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: invalid origin address.", (unsigned long)(i + 1)]];
                continue;
            }

            // Validate destination address
            CMNormalizedAddress *normDest = [normalizer normalizeLine1:destLine1
                                                                line2:nil
                                                                 city:destCity
                                                                state:destState
                                                                  zip:destZip];
            if (!normDest) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: invalid destination address.", (unsigned long)(i + 1)]];
                continue;
            }

            // Parse dates
            NSDate *startDate = [isoFmt dateFromString:depStart];
            NSDate *endDate = [isoFmt dateFromString:depEnd];
            if (!startDate || !endDate) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: invalid departure dates.", (unsigned long)(i + 1)]];
                continue;
            }
            if ([endDate compare:startDate] != NSOrderedDescending) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: departure end must be after start.", (unsigned long)(i + 1)]];
                continue;
            }

            // Vehicle type
            NSString *vehicleType = vType.lowercaseString;
            NSSet *validVehicles = [NSSet setWithObjects:CMVehicleTypeBike, CMVehicleTypeCar,
                                    CMVehicleTypeVan, CMVehicleTypeTruck, nil];
            if (![validVehicles containsObject:vehicleType]) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: invalid vehicle type '%@'.", (unsigned long)(i + 1), vType]];
                continue;
            }

            // Capacity
            double volume = volStr.doubleValue;
            double weight = wgtStr.doubleValue;
            if (volume <= 0) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: volume must be > 0.", (unsigned long)(i + 1)]];
                continue;
            }
            if (weight <= 0) {
                [rejections addObject:[NSString stringWithFormat:@"Row %lu: weight must be > 0.", (unsigned long)(i + 1)]];
                continue;
            }

            // Build address objects
            CMAddress *originAddr = [CMAddress new];
            originAddr.line1 = normOrigin.line1;
            originAddr.city = normOrigin.city;
            originAddr.stateAbbr = normOrigin.stateAbbr;
            originAddr.zip = normOrigin.zip;
            originAddr.normalizedKey = normOrigin.normalizedKey;

            CMAddress *destAddr = [CMAddress new];
            destAddr.line1 = normDest.line1;
            destAddr.city = normDest.city;
            destAddr.stateAbbr = normDest.stateAbbr;
            destAddr.zip = normDest.zip;
            destAddr.normalizedKey = normDest.normalizedKey;

            // Create itinerary
            CMItinerary *it = [repo insertItinerary];
            it.originAddress = originAddr;
            it.destinationAddress = destAddr;
            it.departureWindowStart = startDate;
            it.departureWindowEnd = endDate;
            it.vehicleType = vehicleType;
            it.vehicleCapacityVolumeL = volume;
            it.vehicleCapacityWeightKg = weight;
            it.courierId = courierId;
            it.status = CMItineraryStatusDraft;

            [created addObject:it];
        }

        // Save
        NSError *saveErr = nil;
        BOOL saved = [ctx cm_saveWithError:&saveErr];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (!saved) {
                completion(nil, saveErr ?: [CMError errorWithCode:CMErrorCodeCoreDataSaveFailed
                                                          message:@"Failed to save imported itineraries."]);
                return;
            }

            if (rejections.count > 0 && created.count == 0) {
                // All rows rejected
                NSDictionary *info = @{ CMItineraryImporterRejectedRowsKey: [rejections copy] };
                NSError *err = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                              message:@"All rows were rejected."
                                             userInfo:info];
                completion(nil, err);
                return;
            }

            if (rejections.count > 0) {
                // Partial success — return itineraries but include rejections in error
                NSDictionary *info = @{ CMItineraryImporterRejectedRowsKey: [rejections copy] };
                NSError *warn = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                               message:[NSString stringWithFormat:@"%lu row(s) rejected.",
                                                        (unsigned long)rejections.count]
                                              userInfo:info];
                completion(created, warn);
                return;
            }

            completion(created, nil);
        });
    }];
}

#pragma mark - CSV Parsing

- (NSArray<NSDictionary<NSString *, NSString *> *> *)parseCSVRows:(NSString *)raw
                                                             error:(NSError **)error {
    NSArray<NSString *> *lines = [raw componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *nonEmpty = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            [nonEmpty addObject:trimmed];
        }
    }

    if (nonEmpty.count < 2) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                    message:@"CSV file must have a header row and at least one data row."];
        }
        return nil;
    }

    // Parse header
    NSArray<NSString *> *headerFields = CMParseCSVLine(nonEmpty[0]);
    NSArray<NSString *> *expected = CMImportExpectedColumns();

    // Normalize header field names for comparison
    NSMutableArray<NSString *> *normalizedHeader = [NSMutableArray array];
    for (NSString *h in headerFields) {
        NSString *norm = [[h stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        [normalizedHeader addObject:norm];
    }

    if (normalizedHeader.count < expected.count) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                    message:[NSString stringWithFormat:
                                             @"CSV header has %lu columns, expected %lu.",
                                             (unsigned long)normalizedHeader.count,
                                             (unsigned long)expected.count]];
        }
        return nil;
    }

    // Build column index map
    NSMutableDictionary<NSString *, NSNumber *> *colMap = [NSMutableDictionary dictionary];
    for (NSString *col in expected) {
        NSUInteger idx = [normalizedHeader indexOfObject:col];
        if (idx == NSNotFound) {
            if (error) {
                *error = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                        message:[NSString stringWithFormat:@"Missing CSV column: %@", col]];
            }
            return nil;
        }
        colMap[col] = @(idx);
    }

    // Parse data rows
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray array];
    for (NSUInteger i = 1; i < nonEmpty.count; i++) {
        NSArray<NSString *> *fields = CMParseCSVLine(nonEmpty[i]);
        NSMutableDictionary<NSString *, NSString *> *rowDict = [NSMutableDictionary dictionary];
        for (NSString *col in expected) {
            NSUInteger colIdx = colMap[col].unsignedIntegerValue;
            if (colIdx < fields.count) {
                rowDict[col] = fields[colIdx];
            } else {
                rowDict[col] = @"";
            }
        }
        [result addObject:rowDict];
    }

    return result;
}

#pragma mark - JSON Parsing

- (NSArray<NSDictionary<NSString *, NSString *> *> *)parseJSONRows:(NSString *)raw
                                                              error:(NSError **)error {
    NSData *jsonData = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&jsonError];
    if (jsonError || ![parsed isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeImportSchemaInvalid
                                    message:@"JSON must be an array of objects."];
        }
        return nil;
    }

    NSArray *arr = (NSArray *)parsed;
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *result = [NSMutableArray array];

    for (id item in arr) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *dict = (NSDictionary *)item;
        NSMutableDictionary<NSString *, NSString *> *rowDict = [NSMutableDictionary dictionary];
        for (NSString *key in CMImportExpectedColumns()) {
            id val = dict[key];
            if ([val isKindOfClass:[NSString class]]) {
                rowDict[key] = val;
            } else if ([val isKindOfClass:[NSNumber class]]) {
                rowDict[key] = [val stringValue];
            } else {
                rowDict[key] = @"";
            }
        }
        [result addObject:rowDict];
    }

    return result;
}

@end
