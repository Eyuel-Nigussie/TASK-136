//
//  CMScoringEngine.m
//  CourierMatch
//

#import "CMScoringEngine.h"
#import "CMDeliveryScorecard.h"
#import "CMRubricTemplate.h"
#import "CMOrder.h"
#import "CMAttachment.h"
#import "CMAutoScorerProtocol.h"
#import "CMAutoScorerRegistry.h"
#import "CMRubricRepository.h"
#import "CMScorecardRepository.h"
#import "CMAttachmentRepository.h"
#import "CMTenantContext.h"
#import "CMAuditService.h"
#import "CMUserAccount.h"
#import "CMError.h"
#import "CMDebugLogger.h"

NSString * const CMAutoScorerResultPointsKey    = @"points";
NSString * const CMAutoScorerResultMaxPointsKey  = @"maxPoints";
NSString * const CMAutoScorerResultEvidenceKey   = @"evidence";

NSString * const CMRubricUpgradeAvailableKey      = @"upgradeAvailable";
NSString * const CMRubricUpgradeLatestVersionKey  = @"latestVersion";
NSString * const CMRubricUpgradeLatestRubricIdKey = @"latestRubricId";

/// Rubric item dictionary keys.
static NSString * const kItemKeyKey        = @"itemKey";
static NSString * const kItemLabelKey      = @"label";
static NSString * const kItemModeKey       = @"mode";
static NSString * const kItemMaxPointsKey  = @"maxPoints";
static NSString * const kItemAutoEvalKey   = @"autoEvaluator";
static NSString * const kItemInstructionsKey = @"instructions";

/// Mode values.
static NSString * const kModeAutomatic = @"automatic";
static NSString * const kModeManual    = @"manual";

/// Result keys for stored automated/manual result dicts.
static NSString * const kResultItemKeyKey   = @"itemKey";
static NSString * const kResultPointsKey    = @"points";
static NSString * const kResultMaxPointsKey = @"maxPoints";
static NSString * const kResultEvidenceKey  = @"evidence";
static NSString * const kResultNotesKey     = @"notes";

@interface CMScoringEngine ()
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMScoringEngine

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    self = [super init];
    if (self) {
        _context = context;
    }
    return self;
}

#pragma mark - Create Scorecard

- (CMDeliveryScorecard *)createScorecardForOrder:(CMOrder *)order
                                       courierId:(NSString *)courierId
                                           error:(NSError **)error {
    NSParameterAssert(order);
    NSParameterAssert(courierId.length > 0);

    // 1. Fetch the active rubric template for the current tenant.
    CMRubricRepository *rubricRepo = [[CMRubricRepository alloc] initWithContext:self.context];
    NSError *rubricErr = nil;
    CMRubricTemplate *rubric = [rubricRepo activeRubricForTenant:&rubricErr];
    if (!rubric) {
        NSString *msg = @"No active rubric template found for tenant";
        CMLogError(@"scoring.engine", @"%@", msg);
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:msg
                            underlyingError:rubricErr];
        }
        return nil;
    }

    // 2. Fetch attachments for this order.
    CMAttachmentRepository *attachmentRepo = [[CMAttachmentRepository alloc] initWithContext:self.context];
    NSError *attachErr = nil;
    NSArray<CMAttachment *> *attachments = [attachmentRepo attachmentsForOwner:@"Order"
                                                                       ownerId:order.orderId
                                                                         error:&attachErr];
    if (!attachments) {
        attachments = @[];
    }

    // 3. Create the scorecard entity.
    CMScorecardRepository *scorecardRepo = [[CMScorecardRepository alloc] initWithContext:self.context];
    CMDeliveryScorecard *scorecard = [scorecardRepo insertScorecard];
    scorecard.orderId       = order.orderId;
    scorecard.courierId     = courierId;
    scorecard.rubricId      = rubric.rubricId;
    scorecard.rubricVersion = rubric.rubricVersion;

    // 4. Run automatic scorers for each automatic rubric item.
    NSMutableArray *automatedResults = [NSMutableArray array];
    CMAutoScorerRegistry *registry = [CMAutoScorerRegistry shared];

    for (NSDictionary *item in rubric.items) {
        NSString *mode = item[kItemModeKey];
        if (![mode isEqualToString:kModeAutomatic]) {
            continue;
        }

        NSString *itemKey       = item[kItemKeyKey];
        NSString *autoEvaluator = item[kItemAutoEvalKey];
        double    maxPoints     = [item[kItemMaxPointsKey] doubleValue];

        id<CMAutoScorerProtocol> scorer = [registry scorerForKey:autoEvaluator];
        if (!scorer) {
            CMLogWarn(@"scoring.engine", @"No scorer registered for evaluator '%@', skipping item '%@'",
                      autoEvaluator, itemKey);
            continue;
        }

        NSError *evalErr = nil;
        NSDictionary *result = [scorer evaluateForOrder:order
                                            attachments:attachments
                                                  error:&evalErr];
        if (!result) {
            CMLogWarn(@"scoring.engine", @"Scorer '%@' failed for item '%@': %@",
                      autoEvaluator, itemKey, evalErr.localizedDescription);
            // Record a zero-point result for failed evaluations.
            [automatedResults addObject:@{
                kResultItemKeyKey:   itemKey,
                kResultPointsKey:    @(0.0),
                kResultMaxPointsKey: @(maxPoints),
                kResultEvidenceKey:  [NSString stringWithFormat:@"Evaluation error: %@",
                                      evalErr.localizedDescription ?: @"unknown"]
            }];
            continue;
        }

        // Scale the result by the rubric item's maxPoints.
        double rawPoints    = [result[CMAutoScorerResultPointsKey] doubleValue];
        double rawMaxPoints = [result[CMAutoScorerResultMaxPointsKey] doubleValue];
        double scaledPoints = (rawMaxPoints > 0) ? (rawPoints / rawMaxPoints) * maxPoints : 0.0;

        [automatedResults addObject:@{
            kResultItemKeyKey:   itemKey,
            kResultPointsKey:    @(scaledPoints),
            kResultMaxPointsKey: @(maxPoints),
            kResultEvidenceKey:  result[CMAutoScorerResultEvidenceKey] ?: @""
        }];
    }

    scorecard.automatedResults = [automatedResults copy];
    scorecard.manualResults    = @[];

    CMLogInfo(@"scoring.engine", @"Created scorecard %@ for order %@ (rubric %@ v%lld, %lu auto results)",
              scorecard.scorecardId, order.orderId, rubric.rubricId, rubric.rubricVersion,
              (unsigned long)automatedResults.count);

    // 5. Write audit entry for scorecard creation.
    NSDictionary *afterSnapshot = [self snapshotForScorecard:scorecard];
    [[CMAuditService shared] recordAction:@"scorecard.create"
                               targetType:@"DeliveryScorecard"
                                 targetId:scorecard.scorecardId
                               beforeJSON:nil
                                afterJSON:afterSnapshot
                                   reason:@"Scorecard created from active rubric"
                               completion:nil];

    return scorecard;
}

#pragma mark - Rubric Upgrade Check (Q18)

- (NSDictionary *)checkRubricUpgradeAvailable:(CMDeliveryScorecard *)scorecard {
    NSParameterAssert(scorecard);

    CMRubricRepository *rubricRepo = [[CMRubricRepository alloc] initWithContext:self.context];
    NSError *err = nil;
    CMRubricTemplate *activeRubric = [rubricRepo activeRubricForTenant:&err];

    if (!activeRubric) {
        return @{ CMRubricUpgradeAvailableKey: @NO };
    }

    // Check if the active rubric has a newer version than the scorecard's.
    BOOL upgradeAvailable = NO;
    if ([activeRubric.rubricId isEqualToString:scorecard.rubricId]) {
        upgradeAvailable = (activeRubric.rubricVersion > scorecard.rubricVersion);
    } else {
        // Different rubric ID entirely means a new rubric replaced the old one.
        upgradeAvailable = YES;
    }

    if (upgradeAvailable) {
        return @{
            CMRubricUpgradeAvailableKey:      @YES,
            CMRubricUpgradeLatestVersionKey:  @(activeRubric.rubricVersion),
            CMRubricUpgradeLatestRubricIdKey: activeRubric.rubricId
        };
    }

    return @{ CMRubricUpgradeAvailableKey: @NO };
}

#pragma mark - Upgrade Scorecard Rubric (Q18)

- (CMDeliveryScorecard *)upgradeScorecardRubric:(CMDeliveryScorecard *)scorecard
                                          error:(NSError **)error {
    NSParameterAssert(scorecard);

    if ([scorecard isFinalized]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeScorecardAlreadyFinalized
                                    message:@"Cannot upgrade a finalized scorecard; use an Appeal instead"];
        }
        return nil;
    }

    // Verify upgrade is actually available.
    NSDictionary *upgradeInfo = [self checkRubricUpgradeAvailable:scorecard];
    if (![upgradeInfo[CMRubricUpgradeAvailableKey] boolValue]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeRubricVersionMismatch
                                    message:@"No newer rubric version available"];
        }
        return nil;
    }

    // Fetch the order to re-run automatic scorers.
    CMOrder *order = [self orderForScorecard:scorecard error:error];
    if (!order) {
        return nil;
    }

    // Create the new scorecard linked to the old one.
    NSDictionary *beforeSnapshot = [self snapshotForScorecard:scorecard];

    CMDeliveryScorecard *newScorecard = [self createScorecardForOrder:order
                                                           courierId:scorecard.courierId
                                                               error:error];
    if (!newScorecard) {
        return nil;
    }

    newScorecard.supersedesScorecardId = scorecard.scorecardId;

    NSDictionary *afterSnapshot = [self snapshotForScorecard:newScorecard];

    // Write rubric upgrade audit entry.
    [[CMAuditService shared] recordAction:@"scorecard.rubric_upgraded"
                               targetType:@"DeliveryScorecard"
                                 targetId:newScorecard.scorecardId
                               beforeJSON:beforeSnapshot
                                afterJSON:afterSnapshot
                                   reason:[NSString stringWithFormat:
                                           @"Rubric upgraded from v%lld to v%lld (supersedes %@)",
                                           scorecard.rubricVersion,
                                           newScorecard.rubricVersion,
                                           scorecard.scorecardId]
                               completion:nil];

    CMLogInfo(@"scoring.engine", @"Upgraded scorecard %@ -> %@ (rubric v%lld -> v%lld)",
              scorecard.scorecardId, newScorecard.scorecardId,
              scorecard.rubricVersion, newScorecard.rubricVersion);

    return newScorecard;
}

#pragma mark - Manual Grading

- (BOOL)recordManualGrade:(CMDeliveryScorecard *)scorecard
                  itemKey:(NSString *)itemKey
                   points:(double)points
                    notes:(NSString *)notes
                    error:(NSError **)error {
    NSParameterAssert(scorecard);
    NSParameterAssert(itemKey.length > 0);

    // 0. Role check: only reviewers and admins may record manual grades.
    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc.currentRole isEqualToString:CMUserRoleReviewer] &&
        ![tc.currentRole isEqualToString:CMUserRoleAdmin]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only reviewers and admins may record manual grades"];
        }
        return NO;
    }

    // 1. Reject if finalized.
    if ([scorecard isFinalized]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeScorecardAlreadyFinalized
                                    message:@"Cannot modify a finalized scorecard"];
        }
        return NO;
    }

    // 2. Find the rubric item definition to validate against.
    NSDictionary *rubricItem = [self rubricItemForScorecard:scorecard itemKey:itemKey error:error];
    if (!rubricItem) {
        return NO;
    }

    NSString *mode = rubricItem[kItemModeKey];
    if (![mode isEqualToString:kModeManual]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Item '%@' is not a manual grading item", itemKey]];
        }
        return NO;
    }

    double maxPoints = [rubricItem[kItemMaxPointsKey] doubleValue];

    // 3. Validate point bounds.
    if (points < 0.0) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Points (%.2f) cannot be negative", points]];
        }
        return NO;
    }
    if (points > maxPoints) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Points (%.2f) exceed maxPoints (%.2f) for item '%@'",
                                             points, maxPoints, itemKey]];
        }
        return NO;
    }

    // 4. Mandatory notes when below half of maxPoints.
    double halfMax = maxPoints / 2.0;
    if (points < halfMax && (!notes || notes.length == 0)) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Notes are mandatory when points (%.2f) are below half of "
                                             @"maxPoints (%.2f) for item '%@'",
                                             points, maxPoints, itemKey]];
        }
        return NO;
    }

    // 5. Build the manual result entry.
    NSDictionary *manualResult = @{
        kResultItemKeyKey:   itemKey,
        kResultPointsKey:    @(points),
        kResultMaxPointsKey: @(maxPoints),
        kResultNotesKey:     notes ?: @""
    };

    // 6. Upsert into manualResults (replace existing entry for same itemKey).
    NSMutableArray *manualResults = [NSMutableArray arrayWithArray:scorecard.manualResults ?: @[]];
    NSUInteger existingIndex = NSNotFound;
    for (NSUInteger i = 0; i < manualResults.count; i++) {
        if ([manualResults[i][kResultItemKeyKey] isEqualToString:itemKey]) {
            existingIndex = i;
            break;
        }
    }

    NSDictionary *beforeSnapshot = [self snapshotForScorecard:scorecard];

    if (existingIndex != NSNotFound) {
        [manualResults replaceObjectAtIndex:existingIndex withObject:manualResult];
    } else {
        [manualResults addObject:manualResult];
    }

    scorecard.manualResults = [manualResults copy];
    scorecard.updatedAt = [NSDate date];

    NSDictionary *afterSnapshot = [self snapshotForScorecard:scorecard];

    // 7. Audit trail.
    [[CMAuditService shared] recordAction:@"scorecard.manual_grade"
                               targetType:@"DeliveryScorecard"
                                 targetId:scorecard.scorecardId
                               beforeJSON:beforeSnapshot
                                afterJSON:afterSnapshot
                                   reason:[NSString stringWithFormat:
                                           @"Manual grade for item '%@': %.2f / %.2f",
                                           itemKey, points, maxPoints]
                               completion:nil];

    CMLogInfo(@"scoring.engine", @"Recorded manual grade for scorecard %@, item %@: %.2f/%.2f",
              scorecard.scorecardId, itemKey, points, maxPoints);

    return YES;
}

#pragma mark - Finalize Scorecard

- (BOOL)finalizeScorecard:(CMDeliveryScorecard *)scorecard
                    error:(NSError **)error {
    NSParameterAssert(scorecard);

    // 0. Role check: only reviewers and admins may finalize scorecards.
    CMTenantContext *tc0 = [CMTenantContext shared];
    if (![tc0.currentRole isEqualToString:CMUserRoleReviewer] &&
        ![tc0.currentRole isEqualToString:CMUserRoleAdmin]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only reviewers and admins may finalize scorecards"];
        }
        return NO;
    }

    // 1. Reject if already finalized.
    if ([scorecard isFinalized]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeScorecardAlreadyFinalized
                                    message:@"Scorecard is already finalized"];
        }
        return NO;
    }

    // 2. Validate that all rubric items have been scored.
    CMRubricRepository *rubricRepo = [[CMRubricRepository alloc] initWithContext:self.context];
    NSError *rubricErr = nil;
    CMRubricTemplate *rubric = [rubricRepo findById:scorecard.rubricId
                                      rubricVersion:scorecard.rubricVersion
                                              error:&rubricErr];
    if (!rubric) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Cannot find rubric %@ v%lld for finalization",
                                             scorecard.rubricId, scorecard.rubricVersion]
                            underlyingError:rubricErr];
        }
        return NO;
    }

    // Build sets of scored item keys.
    NSMutableSet<NSString *> *scoredAutoKeys = [NSMutableSet set];
    for (NSDictionary *result in scorecard.automatedResults) {
        [scoredAutoKeys addObject:result[kResultItemKeyKey]];
    }
    NSMutableSet<NSString *> *scoredManualKeys = [NSMutableSet set];
    for (NSDictionary *result in scorecard.manualResults) {
        [scoredManualKeys addObject:result[kResultItemKeyKey]];
    }

    // Check each rubric item has a corresponding result.
    for (NSDictionary *item in rubric.items) {
        NSString *itemKey = item[kItemKeyKey];
        NSString *mode    = item[kItemModeKey];

        if ([mode isEqualToString:kModeAutomatic]) {
            if (![scoredAutoKeys containsObject:itemKey]) {
                if (error) {
                    *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                            message:[NSString stringWithFormat:
                                                     @"Missing automatic score for item '%@'", itemKey]];
                }
                return NO;
            }
        } else if ([mode isEqualToString:kModeManual]) {
            if (![scoredManualKeys containsObject:itemKey]) {
                if (error) {
                    *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                            message:[NSString stringWithFormat:
                                                     @"Missing manual grade for item '%@'", itemKey]];
                }
                return NO;
            }
        }
    }

    // 3. Compute totals.
    NSDictionary *beforeSnapshot = [self snapshotForScorecard:scorecard];

    double totalPoints = 0.0;
    double maxPoints   = 0.0;

    for (NSDictionary *result in scorecard.automatedResults) {
        totalPoints += [result[kResultPointsKey] doubleValue];
        maxPoints   += [result[kResultMaxPointsKey] doubleValue];
    }
    for (NSDictionary *result in scorecard.manualResults) {
        totalPoints += [result[kResultPointsKey] doubleValue];
        maxPoints   += [result[kResultMaxPointsKey] doubleValue];
    }

    scorecard.totalPoints = totalPoints;
    scorecard.maxPoints   = maxPoints;

    // 4. Mark as finalized.
    CMTenantContext *tc = [CMTenantContext shared];
    scorecard.finalizedAt = [NSDate date];
    scorecard.finalizedBy = tc.currentUserId;
    scorecard.updatedAt   = [NSDate date];

    NSDictionary *afterSnapshot = [self snapshotForScorecard:scorecard];

    // 5. Audit trail.
    [[CMAuditService shared] recordAction:@"scorecard.finalize"
                               targetType:@"DeliveryScorecard"
                                 targetId:scorecard.scorecardId
                               beforeJSON:beforeSnapshot
                                afterJSON:afterSnapshot
                                   reason:[NSString stringWithFormat:
                                           @"Scorecard finalized: %.2f / %.2f points",
                                           totalPoints, maxPoints]
                               completion:nil];

    CMLogInfo(@"scoring.engine", @"Finalized scorecard %@: %.2f / %.2f",
              scorecard.scorecardId, totalPoints, maxPoints);

    return YES;
}

#pragma mark - Private Helpers

/// Creates a snapshot dictionary of the scorecard's current state for audit logging.
- (NSDictionary *)snapshotForScorecard:(CMDeliveryScorecard *)scorecard {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"scorecardId"]   = scorecard.scorecardId ?: @"";
    snapshot[@"orderId"]       = scorecard.orderId ?: @"";
    snapshot[@"courierId"]     = scorecard.courierId ?: @"";
    snapshot[@"rubricId"]      = scorecard.rubricId ?: @"";
    snapshot[@"rubricVersion"] = @(scorecard.rubricVersion);
    snapshot[@"totalPoints"]   = @(scorecard.totalPoints);
    snapshot[@"maxPoints"]     = @(scorecard.maxPoints);

    if (scorecard.supersedesScorecardId) {
        snapshot[@"supersedesScorecardId"] = scorecard.supersedesScorecardId;
    }
    if (scorecard.automatedResults) {
        snapshot[@"automatedResults"] = scorecard.automatedResults;
    }
    if (scorecard.manualResults) {
        snapshot[@"manualResults"] = scorecard.manualResults;
    }
    if (scorecard.finalizedAt) {
        snapshot[@"finalizedAt"] = [scorecard.finalizedAt description];
    }
    if (scorecard.finalizedBy) {
        snapshot[@"finalizedBy"] = scorecard.finalizedBy;
    }

    return [snapshot copy];
}

/// Finds the rubric item definition matching the given itemKey on a scorecard's rubric version.
- (NSDictionary *)rubricItemForScorecard:(CMDeliveryScorecard *)scorecard
                                 itemKey:(NSString *)itemKey
                                   error:(NSError **)error {
    CMRubricRepository *rubricRepo = [[CMRubricRepository alloc] initWithContext:self.context];
    NSError *rubricErr = nil;
    CMRubricTemplate *rubric = [rubricRepo findById:scorecard.rubricId
                                      rubricVersion:scorecard.rubricVersion
                                              error:&rubricErr];
    if (!rubric) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Cannot find rubric %@ v%lld",
                                             scorecard.rubricId, scorecard.rubricVersion]
                            underlyingError:rubricErr];
        }
        return nil;
    }

    for (NSDictionary *item in rubric.items) {
        if ([item[kItemKeyKey] isEqualToString:itemKey]) {
            return item;
        }
    }

    if (error) {
        *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                message:[NSString stringWithFormat:
                                         @"Item key '%@' not found in rubric %@ v%lld",
                                         itemKey, scorecard.rubricId, scorecard.rubricVersion]];
    }
    return nil;
}

/// Fetches the order associated with a scorecard.
- (CMOrder *)orderForScorecard:(CMDeliveryScorecard *)scorecard error:(NSError **)error {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Order"];
    request.predicate = [NSPredicate predicateWithFormat:@"orderId == %@", scorecard.orderId];
    request.fetchLimit = 1;

    NSError *fetchErr = nil;
    NSArray *results = [self.context executeFetchRequest:request error:&fetchErr];
    if (!results || results.count == 0) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Order '%@' not found for scorecard upgrade",
                                             scorecard.orderId]
                            underlyingError:fetchErr];
        }
        return nil;
    }
    return results.firstObject;
}

@end
