#import "CMDispute.h"
NSString * const CMDisputeStatusOpen     = @"open";
NSString * const CMDisputeStatusInReview = @"in_review";
NSString * const CMDisputeStatusResolved = @"resolved";
NSString * const CMDisputeStatusRejected = @"rejected";
@implementation CMDispute
@dynamic disputeId, tenantId, orderId, openedBy, openedAt;
@dynamic reason, reasonCategory, status, reviewerId, resolution, closedAt;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
