//
//  CMAppealService.h
//  CourierMatch
//
//  Appeal workflow service. Manages the lifecycle of appeals against finalized
//  scorecards: opening, reviewer assignment, decision submission, and closure.
//  All state changes write audit entries via CMAuditService.
//  See design.md §10.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMAppeal;
@class CMDispute;
@class CMDeliveryScorecard;

NS_ASSUME_NONNULL_BEGIN

@interface CMAppealService : NSObject

/// Initialize with a Core Data context.
/// @param context The NSManagedObjectContext to operate in.
- (instancetype)initWithContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Opens a new appeal against a finalized scorecard.
/// Creates the appeal with a locked before-score snapshot.
/// @param dispute   Optional linked dispute (may be nil for direct appeals).
/// @param scorecard The finalized scorecard being appealed.
/// @param reason    Required reason for the appeal.
/// @param error     Set on failure.
/// @return The newly created CMAppeal, or nil on error.
- (nullable CMAppeal *)openAppeal:(nullable CMDispute *)dispute
                        scorecard:(CMDeliveryScorecard *)scorecard
                           reason:(NSString *)reason
                            error:(NSError **)error;

/// Assigns or reassigns a reviewer to an appeal.
/// @param reviewerId The userId of the reviewer to assign.
/// @param appeal     The appeal to update.
/// @param error      Set on failure.
/// @return YES on success, NO on failure.
- (BOOL)assignReviewer:(NSString *)reviewerId
              toAppeal:(CMAppeal *)appeal
                 error:(NSError **)error;

/// Submits a decision on an appeal.
/// Records the decision, after-score snapshot, and writes audit entry.
/// If monetaryImpact is YES, the caller must have Finance role.
/// @param decision    One of CMAppealDecisionUphold, CMAppealDecisionAdjust, CMAppealDecisionReject.
/// @param appeal      The appeal to decide.
/// @param afterScores Optional dictionary of adjusted scores (required for "adjust" decision).
/// @param notes       Decision notes (required).
/// @param error       Set on failure.
/// @return YES on success, NO on failure.
- (BOOL)submitDecision:(NSString *)decision
                appeal:(CMAppeal *)appeal
           afterScores:(nullable NSDictionary *)afterScores
                 notes:(NSString *)notes
                 error:(NSError **)error;

/// Closes the appeal and updates the linked dispute if any.
/// If monetaryImpact is YES on the appeal, the current user must have Finance role.
/// @param appeal     The appeal to close.
/// @param resolution Resolution text for the linked dispute.
/// @param error      Set on failure.
/// @return YES on success, NO on failure.
- (BOOL)closeAppeal:(CMAppeal *)appeal
         resolution:(NSString *)resolution
              error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
