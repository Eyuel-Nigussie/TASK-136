#import "CMRepository.h"
#import "CMAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface CMAttachmentRepository : CMRepository
- (CMAttachment *)insertAttachment;
- (nullable CMAttachment *)findById:(NSString *)attachmentId error:(NSError **)error;
- (nullable NSArray<CMAttachment *> *)attachmentsForOwner:(NSString *)ownerType
                                                    ownerId:(NSString *)ownerId
                                                      error:(NSError **)error;
- (nullable NSArray<CMAttachment *> *)expiredBefore:(NSDate *)date
                                                limit:(NSUInteger)limit
                                                error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
