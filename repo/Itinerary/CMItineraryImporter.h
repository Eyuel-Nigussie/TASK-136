//
//  CMItineraryImporter.h
//  CourierMatch
//
//  Imports itineraries from CSV or JSON files. Enforces file size limits,
//  row caps, field-length limits, BOM stripping, and formula-injection
//  neutralization per questions.md Q12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMItinerary;

/// User info key containing an NSArray of per-row rejection descriptions.
extern NSString * const CMItineraryImporterRejectedRowsKey;

@interface CMItineraryImporter : NSObject

/// Imports itineraries from a CSV or JSON file at the given URL.
/// Format is detected by file extension (.csv or .json).
///
/// Hardening (Q12):
///   - 2 MB file-size limit
///   - 10,000 row cap
///   - 512-char field limit
///   - BOM stripped
///   - Formula injection neutralized (leading =, +, @, -)
///   - Addresses validated via CMAddressNormalizer
///
/// CSV columns (order matters):
///   origin_line1, origin_city, origin_state, origin_zip,
///   dest_line1, dest_city, dest_state, dest_zip,
///   departure_start, departure_end, vehicle_type,
///   capacity_volume, capacity_weight
///
/// JSON: array of objects with the same field names as keys.
///
/// @param fileURL    Local file URL to import.
/// @param completion Called on the main queue with persisted itinerary objects
///                   or an error. The error's userInfo may contain
///                   CMItineraryImporterRejectedRowsKey with per-row details.
- (void)importFromURL:(NSURL *)fileURL
           completion:(void (^)(NSArray<CMItinerary *> * _Nullable itineraries,
                                NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
