//
//  CMAppeal.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMAppealDecisionUphold;
extern NSString * const CMAppealDecisionAdjust;
extern NSString * const CMAppealDecisionReject;

@interface CMAppeal : NSManagedObject
@property (nonatomic, copy)             NSString       *appealId;
@property (nonatomic, copy)             NSString       *tenantId;
@property (nonatomic, copy)             NSString       *scorecardId;
@property (nonatomic, copy,   nullable) NSString       *disputeId;
@property (nonatomic, copy)             NSString       *reason;
@property (nonatomic, copy)             NSString       *openedBy;
@property (nonatomic, strong)           NSDate         *openedAt;
@property (nonatomic, copy,   nullable) NSString       *assignedReviewerId;
@property (nonatomic, strong, nullable) NSDictionary   *beforeScoreSnapshotJSON;
@property (nonatomic, strong, nullable) NSDictionary   *afterScoreSnapshotJSON;
@property (nonatomic, copy,   nullable) NSString       *decision;
@property (nonatomic, copy,   nullable) NSString       *decidedBy;
@property (nonatomic, strong, nullable) NSDate         *decidedAt;
@property (nonatomic, copy,   nullable) NSString       *decisionNotes;
@property (nonatomic, assign)           BOOL            monetaryImpact;
@property (nonatomic, copy,   nullable) NSString       *auditChainHead;
@property (nonatomic, strong)           NSDate         *createdAt;
@property (nonatomic, strong)           NSDate         *updatedAt;
@property (nonatomic, strong, nullable) NSDate         *deletedAt;
@property (nonatomic, copy,   nullable) NSString       *createdBy;
@property (nonatomic, copy,   nullable) NSString       *updatedBy;
@property (nonatomic, assign)           int64_t         version;
@end

NS_ASSUME_NONNULL_END
