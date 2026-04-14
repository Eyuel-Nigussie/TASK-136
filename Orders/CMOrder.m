//
//  CMOrder.m
//  CourierMatch
//

#import "CMOrder.h"

NSString * const CMOrderStatusNew       = @"new";
NSString * const CMOrderStatusAssigned  = @"assigned";
NSString * const CMOrderStatusPickedUp  = @"picked_up";
NSString * const CMOrderStatusDelivered = @"delivered";
NSString * const CMOrderStatusDisputed  = @"disputed";
NSString * const CMOrderStatusCancelled = @"cancelled";

@implementation CMOrder
@dynamic orderId, tenantId, externalOrderRef, pickupAddress, dropoffAddress;
@dynamic pickupWindowStart, pickupWindowEnd, dropoffWindowStart, dropoffWindowEnd;
@dynamic pickupTimeZoneIdentifier, dropoffTimeZoneIdentifier;
@dynamic parcelVolumeL, parcelWeightKg, requiresVehicleType;
@dynamic status, assignedCourierId, customerNotes, sensitiveCustomerId;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;

- (BOOL)isTerminal {
    return [self.status isEqualToString:CMOrderStatusDelivered] ||
           [self.status isEqualToString:CMOrderStatusCancelled];
}
@end
