//
//  CMLoginHistory.m
//  CourierMatch
//

#import "CMLoginHistory.h"

NSString * const CMLoginOutcomeSuccess        = @"success";
NSString * const CMLoginOutcomeFailed         = @"failed";
NSString * const CMLoginOutcomeLocked         = @"locked";
NSString * const CMLoginOutcomeCaptchaGated   = @"captcha_gated";
NSString * const CMLoginOutcomeCaptchaFailed  = @"captcha_failed";
NSString * const CMLoginOutcomeForcedLogout   = @"forced_logout";

@implementation CMLoginHistory

@dynamic entryId, userId, tenantId, deviceModel, osVersion, appVersion;
@dynamic loggedInAt, loggedOutAt, outcome;
@dynamic createdAt, updatedAt, deletedAt, createdBy, updatedBy, version;

@end
