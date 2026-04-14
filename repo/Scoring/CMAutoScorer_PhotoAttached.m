//
//  CMAutoScorer_PhotoAttached.m
//  CourierMatch
//

#import "CMAutoScorer_PhotoAttached.h"
#import "CMAttachment.h"
#import "CMOrder.h"

@implementation CMAutoScorer_PhotoAttached

- (NSDictionary *)evaluateForOrder:(CMOrder *)order
                       attachments:(NSArray<CMAttachment *> *)attachments
                             error:(NSError **)error {
    NSParameterAssert(order);

    BOOL hasPhoto = NO;
    NSString *matchedFilename = nil;

    for (CMAttachment *att in attachments) {
        if ([att.mimeType hasPrefix:@"image/"]) {
            hasPhoto = YES;
            matchedFilename = att.filename;
            break;
        }
    }

    double points = hasPhoto ? 1.0 : 0.0;
    NSString *evidence;
    if (hasPhoto) {
        evidence = [NSString stringWithFormat:
                    @"Photo attachment found: %@", matchedFilename ?: @"(unknown)"];
    } else {
        evidence = @"No image/* attachment found for order";
    }

    return @{
        CMAutoScorerResultPointsKey:    @(points),
        CMAutoScorerResultMaxPointsKey: @(1.0),
        CMAutoScorerResultEvidenceKey:  evidence
    };
}

@end
