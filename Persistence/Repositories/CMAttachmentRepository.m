#import "CMAttachmentRepository.h"

@implementation CMAttachmentRepository
+ (NSString *)entityName { return @"Attachment"; }

- (CMAttachment *)insertAttachment {
    CMAttachment *a = (CMAttachment *)[self insertStampedObject];
    if (!a.attachmentId) a.attachmentId = [[NSUUID UUID] UUIDString];
    return a;
}
- (CMAttachment *)findById:(NSString *)attachmentId error:(NSError **)error {
    return [self fetchOneWithPredicate:
            [NSPredicate predicateWithFormat:@"attachmentId == %@", attachmentId] error:error];
}
- (NSArray<CMAttachment *> *)attachmentsForOwner:(NSString *)ownerType
                                           ownerId:(NSString *)ownerId
                                             error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"ownerType == %@ AND ownerId == %@", ownerType, ownerId];
    return [self fetchWithPredicate:p
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"capturedAt" ascending:NO]]
                              limit:0 error:error];
}
- (NSArray<CMAttachment *> *)expiredBefore:(NSDate *)date
                                      limit:(NSUInteger)limit
                                      error:(NSError **)error {
    NSPredicate *p = [NSPredicate predicateWithFormat:@"expiresAt < %@", date];
    return [self fetchWithPredicate:p
                    sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"expiresAt" ascending:YES]]
                              limit:limit error:error];
}
@end
