//
//  CMTenant.m
//  CourierMatch
//

#import "CMTenant.h"

NSString * const CMTenantStatusActive    = @"active";
NSString * const CMTenantStatusSuspended = @"suspended";

@implementation CMTenant
@dynamic tenantId, name, status, configJSON;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;
@end
