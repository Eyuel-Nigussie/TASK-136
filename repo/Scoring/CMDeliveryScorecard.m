#import "CMDeliveryScorecard.h"
@implementation CMDeliveryScorecard
@dynamic scorecardId, tenantId, orderId, courierId, rubricId, rubricVersion;
@dynamic supersedesScorecardId, automatedResults, manualResults;
@dynamic totalPoints, maxPoints, finalizedAt, finalizedBy;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
- (BOOL)isFinalized { return self.finalizedAt != nil; }
@end
