#import "CMNotificationRepository.h"
#import "NSManagedObjectContext+CMHelpers.h"

@implementation CMNotificationRepository
+ (NSString *)entityName { return @"NotificationItem"; }

- (CMNotificationItem *)insertNotification {
    CMNotificationItem *n = (CMNotificationItem *)[self insertStampedObject];
    if (!n.notificationId) n.notificationId = [[NSUUID UUID] UUIDString];
    return n;
}

- (NSArray<CMNotificationItem *> *)unreadForUser:(NSString *)userId
                                             limit:(NSUInteger)limit
                                             error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:
                      @"recipientUserId == %@ AND readAt == nil AND status == %@",
                      userId, CMNotificationStatusActive];
    return [self fetchWithPredicate:p
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]]
                              limit:limit
                              error:error];
}

- (NSUInteger)countInBucket:(NSString *)bucket error:(NSError **)error {
    NSFetchRequest *req = [self scopedFetchRequestWithPredicate:
                           [NSPredicate predicateWithFormat:@"rateLimitBucket == %@", bucket]];
    return [self.context countForFetchRequest:req error:error];
}
@end
