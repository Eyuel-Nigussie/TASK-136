//
//  CMLoginHistory.h
//  CourierMatch
//
//  Per-device login history entry per design.md §3.1.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMLoginOutcomeSuccess;
extern NSString * const CMLoginOutcomeFailed;
extern NSString * const CMLoginOutcomeLocked;
extern NSString * const CMLoginOutcomeCaptchaGated;
extern NSString * const CMLoginOutcomeCaptchaFailed;
extern NSString * const CMLoginOutcomeForcedLogout;

@interface CMLoginHistory : NSManagedObject

@property (nonatomic, copy)             NSString *entryId;
@property (nonatomic, copy)             NSString *userId;
@property (nonatomic, copy)             NSString *tenantId;
@property (nonatomic, copy,   nullable) NSString *deviceModel;
@property (nonatomic, copy,   nullable) NSString *osVersion;
@property (nonatomic, copy,   nullable) NSString *appVersion;
@property (nonatomic, strong)           NSDate   *loggedInAt;
@property (nonatomic, strong, nullable) NSDate   *loggedOutAt;
@property (nonatomic, copy)             NSString *outcome;
@property (nonatomic, strong)           NSDate   *createdAt;
@property (nonatomic, strong)           NSDate   *updatedAt;
@property (nonatomic, strong, nullable) NSDate   *deletedAt;
@property (nonatomic, copy,   nullable) NSString *createdBy;
@property (nonatomic, copy,   nullable) NSString *updatedBy;
@property (nonatomic, assign)           int64_t   version;

@end

NS_ASSUME_NONNULL_END
