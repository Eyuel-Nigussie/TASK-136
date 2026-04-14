//
//  CMUserAccount.h
//  CourierMatch
//
//  NSManagedObject subclass for the `UserAccount` entity. Manual codegen per
//  design.md §18 — we control the surface.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const CMUserRoleCourier;
extern NSString * const CMUserRoleDispatcher;
extern NSString * const CMUserRoleReviewer;
extern NSString * const CMUserRoleCustomerService;
extern NSString * const CMUserRoleFinance;
extern NSString * const CMUserRoleAdmin;

extern NSString * const CMUserStatusActive;
extern NSString * const CMUserStatusLocked;
extern NSString * const CMUserStatusDisabled;
extern NSString * const CMUserStatusDeleted;

@interface CMUserAccount : NSManagedObject

@property (nonatomic, copy)             NSString *userId;
@property (nonatomic, copy)             NSString *tenantId;
@property (nonatomic, copy)             NSString *username;
@property (nonatomic, copy,   nullable) NSString *displayName;
@property (nonatomic, strong, nullable) NSData   *passwordHash;
@property (nonatomic, strong, nullable) NSData   *passwordSalt;
@property (nonatomic, assign)           int64_t   passwordIterations;
@property (nonatomic, strong, nullable) NSDate   *passwordUpdatedAt;
@property (nonatomic, copy)             NSString *role;
@property (nonatomic, copy)             NSString *status;
@property (nonatomic, assign)           int16_t   failedAttempts;
@property (nonatomic, strong, nullable) NSDate   *lockUntil;
@property (nonatomic, assign)           BOOL      biometricEnabled;
@property (nonatomic, copy,   nullable) NSString *biometricRefId;
@property (nonatomic, strong, nullable) NSDate   *lastLoginAt;
@property (nonatomic, strong, nullable) NSDate   *forceLogoutAt;
@property (nonatomic, strong)           NSDate   *createdAt;
@property (nonatomic, strong)           NSDate   *updatedAt;
@property (nonatomic, strong, nullable) NSDate   *deletedAt;
@property (nonatomic, copy,   nullable) NSString *createdBy;
@property (nonatomic, copy,   nullable) NSString *updatedBy;
@property (nonatomic, assign)           int64_t   version;

/// Convenience: `YES` iff `status == locked` and `lockUntil` is in the future.
- (BOOL)isCurrentlyLocked;

/// Convenience: `YES` iff `failedAttempts >= 3` and lock has not kicked in yet.
- (BOOL)requiresCaptchaNextAttempt;

@end

NS_ASSUME_NONNULL_END
