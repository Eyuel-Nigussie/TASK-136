//
//  CMDisputeService.h
//  CourierMatch
//
//  Service-layer dispute creation with role/permission/tenant enforcement.
//  Only customer service, couriers, and admins may open disputes.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMDispute;
@class CMOrder;

NS_ASSUME_NONNULL_BEGIN

@interface CMDisputeService : NSObject

- (instancetype)initWithContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Opens a new dispute against an order with full authorization checks.
/// Enforces: authenticated user, allowed role (cs/courier/admin), tenant scoping.
/// @param order     The order being disputed (may be nil if orderId is provided directly).
/// @param orderId   The order ID (used if order is nil).
/// @param reason    Required reason text.
/// @param category  Optional reason category.
/// @param error     Set on failure.
/// @return The newly created CMDispute, or nil on error.
- (nullable CMDispute *)openDisputeForOrder:(nullable CMOrder *)order
                                    orderId:(NSString *)orderId
                                     reason:(NSString *)reason
                                   category:(nullable NSString *)category
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
