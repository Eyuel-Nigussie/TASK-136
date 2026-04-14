//
//  CMScoringEngine.h
//  CourierMatch
//
//  Main scoring engine. Creates scorecards from rubric templates, runs automatic
//  scorers, supports manual grading, handles rubric version upgrades (Q18),
//  and finalizes scorecards immutably.
//  See design.md §9.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMDeliveryScorecard;
@class CMOrder;

NS_ASSUME_NONNULL_BEGIN

/// Info dictionary keys returned by checkRubricUpgradeAvailable:.
extern NSString * const CMRubricUpgradeAvailableKey;       // NSNumber (BOOL)
extern NSString * const CMRubricUpgradeLatestVersionKey;   // NSNumber (int64_t)
extern NSString * const CMRubricUpgradeLatestRubricIdKey;  // NSString

@interface CMScoringEngine : NSObject

/// Initialize with a Core Data context. All entity operations use this context.
/// @param context The NSManagedObjectContext to operate in.
- (instancetype)initWithContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Creates a new scorecard for a delivered order using the active rubric template.
/// Runs all automatic scorers defined in the rubric and captures rubricId + rubricVersion.
/// @param order     The delivered order to score.
/// @param courierId The courier who completed the delivery.
/// @param error     Set on failure.
/// @return The newly created scorecard, or nil on error.
- (nullable CMDeliveryScorecard *)createScorecardForOrder:(CMOrder *)order
                                                courierId:(NSString *)courierId
                                                    error:(NSError **)error;

/// Checks whether a newer rubric version exists than what the scorecard was created with.
/// @param scorecard The scorecard to check.
/// @return Dictionary with CMRubricUpgradeAvailableKey (BOOL), and if YES,
///         CMRubricUpgradeLatestVersionKey and CMRubricUpgradeLatestRubricIdKey.
- (NSDictionary *)checkRubricUpgradeAvailable:(CMDeliveryScorecard *)scorecard;

/// Creates a new scorecard linked via supersedesScorecardId to the old one,
/// using the latest rubric version. Re-runs automatic scorers. Writes audit entry.
/// The original scorecard is NOT modified (it remains as a historical record).
/// @param scorecard The existing scorecard to upgrade.
/// @param error     Set on failure.
/// @return The new scorecard created with the latest rubric version, or nil on error.
- (nullable CMDeliveryScorecard *)upgradeScorecardRubric:(CMDeliveryScorecard *)scorecard
                                                   error:(NSError **)error;

/// Records a manual grade for a specific rubric item on the scorecard.
/// Validates: scorecard not finalized, points within [0, maxPoints], mandatory notes
/// when points < maxPoints / 2.
/// @param scorecard The scorecard to grade.
/// @param itemKey   The rubric item key to grade.
/// @param points    The score to assign (0..maxPoints for that item).
/// @param notes     Grading notes (mandatory when points < maxPoints / 2).
/// @param error     Set on validation failure.
/// @return YES on success, NO on failure.
- (BOOL)recordManualGrade:(CMDeliveryScorecard *)scorecard
                  itemKey:(NSString *)itemKey
                   points:(double)points
                    notes:(nullable NSString *)notes
                    error:(NSError **)error;

/// Finalizes the scorecard: validates all items are filled, computes totals,
/// writes scorecard.finalize audit entry with before/after snapshots, sets
/// finalizedAt/finalizedBy. Scorecard is immutable after this.
/// @param scorecard The scorecard to finalize.
/// @param error     Set on failure.
/// @return YES on success, NO on failure.
- (BOOL)finalizeScorecard:(CMDeliveryScorecard *)scorecard
                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
