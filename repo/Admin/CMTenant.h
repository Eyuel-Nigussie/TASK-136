//
//  CMTenant.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMTenantStatusActive;
extern NSString * const CMTenantStatusSuspended;

@interface CMTenant : NSManagedObject
@property (nonatomic, copy)             NSString      *tenantId;
@property (nonatomic, copy)             NSString      *name;
@property (nonatomic, copy)             NSString      *status;
@property (nonatomic, strong, nullable) NSDictionary  *configJSON;
@property (nonatomic, strong)           NSDate        *createdAt;
@property (nonatomic, strong)           NSDate        *updatedAt;
@property (nonatomic, strong, nullable) NSDate        *deletedAt;
@property (nonatomic, copy,   nullable) NSString      *createdBy;
@property (nonatomic, copy,   nullable) NSString      *updatedBy;
@property (nonatomic, assign)           int64_t        version;
@end

NS_ASSUME_NONNULL_END
