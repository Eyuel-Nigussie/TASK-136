//
//  CMZipMetroTable.h
//  CourierMatch
//
//  Bundled lookup for dense metro ZIP prefixes (3-digit).
//  Loaded from MetroZipPrefixes.plist.
//  See design.md section 5.2 and Q2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMZipMetroTable : NSObject

+ (instancetype)shared;

/// Returns YES if the given ZIP code belongs to a dense metro area.
/// Checks the first 3 digits of the ZIP against the bundled prefix table.
- (BOOL)isMetroZip:(nullable NSString *)zip;

/// Returns YES if both ZIP codes belong to dense metro areas.
- (BOOL)areBothMetroZip1:(nullable NSString *)zip1 zip2:(nullable NSString *)zip2;

/// The urban driving multiplier for when both endpoints are in dense metro areas.
/// Default: 1.35. Overridable via tenant configJSON key "urbanMultiplier".
@property (nonatomic, assign) double urbanMultiplier;

/// The rural/suburban driving multiplier.
/// Default: 1.15. Overridable via tenant configJSON key "ruralMultiplier".
@property (nonatomic, assign) double ruralMultiplier;

/// Returns the appropriate multiplier given whether both endpoints are metro.
- (double)multiplierForBothMetro:(BOOL)bothMetro;

@end

NS_ASSUME_NONNULL_END
