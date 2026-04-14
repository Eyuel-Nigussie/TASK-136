//
//  CMDisputeService.m
//  CourierMatch
//

#import "CMDisputeService.h"
#import "CMDispute.h"
#import "CMOrder.h"
#import "CMOrderRepository.h"
#import "CMDisputeRepository.h"
#import "CMTenantContext.h"
#import "CMPermissionMatrix.h"
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

    // 2. Permission check via centralized RBAC matrix.
    //    Admin always passes; other roles must have 'disputes.open'.
    if (![tc.currentRole isEqualToString:CMUserRoleAdmin] &&
        ![[CMPermissionMatrix shared] hasPermission:@"disputes.open" forRole:tc.currentRole]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Current role does not have disputes.open permission"];
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

    // 3b. Always resolve the order entity to validate it exists in the current tenant.
    //     This prevents disputes against non-existent or cross-tenant order references.
    CMOrder *resolvedOrder = order;
    if (!resolvedOrder) {
        CMOrderRepository *orderRepo = [[CMOrderRepository alloc] initWithContext:self.context];
        resolvedOrder = [orderRepo findByOrderId:resolvedOrderId error:nil];
    }
    if (!resolvedOrder) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Order not found in current tenant; cannot open dispute"];
        }
        return nil;
    }
    // Use the resolved order's ID to ensure consistency.
    resolvedOrderId = resolvedOrder.orderId;

    // 3c. Object-level ownership: couriers may only dispute their own orders.
    if ([tc.currentRole isEqualToString:CMUserRoleCourier]) {
        if (![resolvedOrder.assignedCourierId isEqualToString:tc.currentUserId]) {
            if (error) {
                *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                        message:@"Couriers may only open disputes for orders assigned to them"];
            }
            return nil;
        }
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
