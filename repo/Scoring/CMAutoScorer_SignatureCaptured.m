//
//  CMAutoScorer_SignatureCaptured.m
//  CourierMatch
//

#import "CMAutoScorer_SignatureCaptured.h"
#import "CMAttachment.h"
#import "CMOrder.h"

/// The ownerType used for signature attachments.
static NSString * const kSignatureOwnerType = @"signature";

@implementation CMAutoScorer_SignatureCaptured

- (NSDictionary *)evaluateForOrder:(CMOrder *)order
                       attachments:(NSArray<CMAttachment *> *)attachments
                             error:(NSError **)error {
    NSParameterAssert(order);

    BOOL hasSignature = NO;
    NSString *matchedId = nil;

    for (CMAttachment *att in attachments) {
        // A signature attachment is identified strictly by ownerType == "signature".
        // Filename-based heuristic removed to prevent non-signature files from
        // satisfying this objective scoring criterion.
        if ([att.ownerType.lowercaseString isEqualToString:kSignatureOwnerType]) {
            hasSignature = YES;
            matchedId = att.attachmentId;
            break;
        }
    }

    double points = hasSignature ? 1.0 : 0.0;
    NSString *evidence;
    if (hasSignature) {
        evidence = [NSString stringWithFormat:
                    @"Signature attachment found: %@", matchedId ?: @"(unknown)"];
    } else {
        evidence = @"No signature attachment found for order";
    }

    return @{
        CMAutoScorerResultPointsKey:    @(points),
        CMAutoScorerResultMaxPointsKey: @(1.0),
        CMAutoScorerResultEvidenceKey:  evidence
    };
}

@end
