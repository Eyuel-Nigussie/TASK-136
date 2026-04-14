//
//  CMDisputeService.m
//  CourierMatch
//

#import "CMDisputeService.h"
#import "CMDispute.h"
#import "CMOrder.h"
#import "CMDisputeRepository.h"
#import "CMTenantContext.h"
#import "CMAuditService.h"
#import "CMUserAccount.h"
#import "CMError.h"
#import "CMDebugLogger.h"

@interface CMDisputeService ()
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMDisputeService

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    self = [super init];
    if (self) {
        _context = context;
    }
    return self;
}

- (CMDispute *)openDisputeForOrder:(CMOrder *)order
                           orderId:(NSString *)orderId
                            reason:(NSString *)reason
                          category:(NSString *)category
                             error:(NSError **)error {
    NSParameterAssert(reason.length > 0);

    // 1. Authentication check.
    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"No authenticated user for opening dispute"];
        }
        return nil;
    }

    // 2. Role check: only customer service, couriers, and admins may open disputes.
    if (![tc.currentRole isEqualToString:CMUserRoleCustomerService] &&
        ![tc.currentRole isEqualToString:CMUserRoleCourier] &&
        ![tc.currentRole isEqualToString:CMUserRoleAdmin]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only customer service, couriers, and admins may open disputes"];
        }
        return nil;
    }

    // 3. Validate orderId is provided.
    NSString *resolvedOrderId = order ? order.orderId : orderId;
    if (!resolvedOrderId || resolvedOrderId.length == 0) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Order reference is required to open a dispute"];
        }
        return nil;
    }

    // 4. Create the dispute entity.
    CMDisputeRepository *repo = [[CMDisputeRepository alloc] initWithContext:self.context];
    CMDispute *dispute = [repo insertDispute];
    dispute.orderId = resolvedOrderId;
    dispute.reason = reason;
    dispute.reasonCategory = category;
    dispute.status = CMDisputeStatusOpen;
    dispute.openedBy = tc.currentUserId;
    dispute.openedAt = [NSDate date];

    // 5. Audit trail.
    [[CMAuditService shared] recordAction:@"dispute.open"
                               targetType:@"Dispute"
                                 targetId:dispute.disputeId
                               beforeJSON:nil
                                afterJSON:@{
                                    @"disputeId": dispute.disputeId ?: @"",
                                    @"orderId": resolvedOrderId,
                                    @"reason": reason,
                                    @"category": category ?: @"",
                                    @"openedBy": tc.currentUserId ?: @""
                                }
                                   reason:reason
                               completion:nil];

    CMLogInfo(@"dispute.service", @"Opened dispute %@ for order %@ by %@",
              [CMDebugLogger redact:dispute.disputeId],
              [CMDebugLogger redact:resolvedOrderId],
              [CMDebugLogger redact:tc.currentUserId]);

    return dispute;
}

@end
