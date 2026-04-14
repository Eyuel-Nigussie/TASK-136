#import "CMAppeal.h"
NSString * const CMAppealDecisionUphold = @"uphold";
NSString * const CMAppealDecisionAdjust = @"adjust";
NSString * const CMAppealDecisionReject = @"reject";
@implementation CMAppeal
@dynamic appealId, tenantId, scorecardId, disputeId, reason, openedBy, openedAt;
@dynamic assignedReviewerId, beforeScoreSnapshotJSON, afterScoreSnapshotJSON;
@dynamic decision, decidedBy, decidedAt, decisionNotes, monetaryImpact, auditChainHead;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
