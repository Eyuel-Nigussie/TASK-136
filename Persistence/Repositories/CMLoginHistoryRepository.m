//
//  CMLoginHistoryRepository.m
//  CourierMatch
//

#import "CMLoginHistoryRepository.h"
#import <UIKit/UIKit.h>

@implementation CMLoginHistoryRepository

+ (NSString *)entityName { return @"LoginHistory"; }

- (CMLoginHistory *)recordEntryForUserId:(NSString *)userId
                                 tenantId:(NSString *)tenantId
                                  outcome:(NSString *)outcome {
    // Pre-auth event paths may have no TenantContext; insert manually rather
    // than relying on insertStampedObject's scoping.
    CMLoginHistory *e = [NSEntityDescription insertNewObjectForEntityForName:[[self class] entityName]
                                                     inManagedObjectContext:self.context];
    NSDate *now = [NSDate date];
    e.entryId     = [[NSUUID UUID] UUIDString];
    e.userId      = userId  ?: @"";
    e.tenantId    = tenantId ?: @"";
    e.deviceModel = [UIDevice currentDevice].model;
    e.osVersion   = [UIDevice currentDevice].systemVersion;
    e.appVersion  = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    e.loggedInAt  = now;
    e.outcome     = outcome ?: @"success";
    e.createdAt   = now;
    e.updatedAt   = now;
    e.version     = 1;
    return e;
}

- (NSArray<CMLoginHistory *> *)recentForUserId:(NSString *)userId
                                            limit:(NSUInteger)limit
                                            error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"userId == %@", userId];
    NSArray *sorts = @[[NSSortDescriptor sortDescriptorWithKey:@"loggedInAt" ascending:NO]];
    return [self fetchWithPredicate:p sortDescriptors:sorts limit:limit error:error];
}

@end
