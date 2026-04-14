//
//  CMRubricTemplate.h
//  CourierMatch
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMRubricTemplate : NSManagedObject
@property (nonatomic, copy)             NSString   *rubricId;
@property (nonatomic, copy)             NSString   *tenantId;
@property (nonatomic, copy)             NSString   *name;
@property (nonatomic, assign)           BOOL        active;
@property (nonatomic, assign)           int64_t     rubricVersion;
@property (nonatomic, strong, nullable) NSArray    *items;  // array of RubricItem dicts
@property (nonatomic, strong)           NSDate     *createdAt;
@property (nonatomic, strong)           NSDate     *updatedAt;
@property (nonatomic, strong, nullable) NSDate     *deletedAt;
@property (nonatomic, copy,   nullable) NSString   *createdBy;
@property (nonatomic, copy,   nullable) NSString   *updatedBy;
@property (nonatomic, assign)           int64_t     version;
@end

NS_ASSUME_NONNULL_END
