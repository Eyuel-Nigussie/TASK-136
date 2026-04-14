//
//  CMAuditEntry.h
//  CourierMatch
//
//  Append-only audit entry per design.md §10.3. No updatedAt, deletedAt,
//  version — these records are NEVER updated or soft-deleted.
//

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMAuditEntry : NSManagedObject
@property (nonatomic, copy)             NSString       *entryId;
@property (nonatomic, copy)             NSString       *tenantId;
@property (nonatomic, copy)             NSString       *actorUserId;
@property (nonatomic, copy)             NSString       *actorRole;
@property (nonatomic, copy)             NSString       *action;
@property (nonatomic, copy,   nullable) NSString       *targetType;
@property (nonatomic, copy,   nullable) NSString       *targetId;
@property (nonatomic, strong, nullable) NSDictionary   *beforeJSON;
@property (nonatomic, strong, nullable) NSDictionary   *afterJSON;
@property (nonatomic, copy,   nullable) NSString       *reason;
@property (nonatomic, strong)           NSDate         *createdAt;
@property (nonatomic, strong, nullable) NSData         *prevHash;
@property (nonatomic, strong, nullable) NSData         *entryHash;
@end

NS_ASSUME_NONNULL_END
