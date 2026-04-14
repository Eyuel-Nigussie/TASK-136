//
//  CMAppealService.m
//  CourierMatch
//

#import "CMAppealService.h"
#import "CMAppeal.h"
#import "CMDispute.h"
#import "CMDeliveryScorecard.h"
#import "CMAppealRepository.h"
#import "CMDisputeRepository.h"
#import "CMUserRepository.h"
#import "CMTenantContext.h"
#import "CMAuditService.h"
#import "CMUserAccount.h"
#import "CMPermissionMatrix.h"
#import "CMError.h"
#import "CMDebugLogger.h"

@interface CMAppealService ()
@property (nonatomic, strong) NSManagedObjectContext *context;
@end

@implementation CMAppealService

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    self = [super init];
    if (self) {
        _context = context;
    }
    return self;
}

#pragma mark - Open Appeal

- (CMAppeal *)openAppeal:(CMDispute *)dispute
               scorecard:(CMDeliveryScorecard *)scorecard
                  reason:(NSString *)reason
                   error:(NSError **)error {
    NSParameterAssert(scorecard);
    NSParameterAssert(reason.length > 0);

    // 1. The scorecard must be finalized — appeals only apply to finalized scorecards.
    if (![scorecard isFinalized]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Cannot open an appeal against a non-finalized scorecard"];
        }
        return nil;
    }

    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"No authenticated user for opening appeal"];
        }
        return nil;
    }

    // 1b. Permission check via centralized RBAC matrix.
    //     Admin always passes; other roles must have 'appeals.open'.
    if (![tc.currentRole isEqualToString:CMUserRoleAdmin] &&
        ![[CMPermissionMatrix shared] hasPermission:@"appeals.open" forRole:tc.currentRole]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Current role does not have appeals.open permission"];
        }
        return nil;
    }

    // 1c. Object-level ownership: couriers may only appeal their own scorecards.
    if ([tc.currentRole isEqualToString:CMUserRoleCourier]) {
        if (![scorecard.courierId isEqualToString:tc.currentUserId]) {
            if (error) {
                *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                        message:@"Couriers may only appeal scorecards for their own deliveries"];
            }
            return nil;
        }
    }

    // 2. Create the appeal entity.
    CMAppealRepository *appealRepo = [[CMAppealRepository alloc] initWithContext:self.context];
    CMAppeal *appeal = [appealRepo insertAppeal];
    appeal.scorecardId = scorecard.scorecardId;
    appeal.reason      = reason;
    appeal.openedBy    = tc.currentUserId;
    appeal.openedAt    = [NSDate date];

    // Link to dispute if provided.
    if (dispute) {
        appeal.disputeId = dispute.disputeId;
    }

    // 3. Lock the before-score snapshot (immutable once captured).
    appeal.beforeScoreSnapshotJSON = [self snapshotForScorecard:scorecard];

    CMLogInfo(@"appeals.service", @"Opened appeal %@ for scorecard %@ (dispute: %@)",
              [CMDebugLogger redact:appeal.appealId], [CMDebugLogger redact:scorecard.scorecardId],
              dispute.disputeId ? [CMDebugLogger redact:dispute.disputeId] : @"none");

    // 4. Write audit entry.
    NSDictionary *afterJSON = [self snapshotForAppeal:appeal];
    [[CMAuditService shared] recordAction:@"appeal.open"
                               targetType:@"Appeal"
                                 targetId:appeal.appealId
                               beforeJSON:nil
                                afterJSON:afterJSON
                                   reason:reason
                               completion:nil];

    // Persist to store.
    NSError *saveErr = nil;
    if (![self.context save:&saveErr]) {
        if (error) { *error = saveErr; }
        return nil;
    }

    return appeal;
}

#pragma mark - Assign Reviewer

- (BOOL)assignReviewer:(NSString *)reviewerId
              toAppeal:(CMAppeal *)appeal
                 error:(NSError **)error {
    NSParameterAssert(reviewerId.length > 0);
    NSParameterAssert(appeal);

    // 0. Role check: only admins and reviewers may assign reviewers to appeals.
    CMTenantContext *tcAssign = [CMTenantContext shared];
    if (![tcAssign.currentRole isEqualToString:CMUserRoleAdmin] &&
        ![tcAssign.currentRole isEqualToString:CMUserRoleReviewer]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only admins and reviewers may assign reviewers to appeals"];
        }
        return NO;
    }

    // Cannot assign reviewer to a decided appeal.
    if (appeal.decision) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Cannot assign reviewer to an appeal that already has a decision"];
        }
        return NO;
    }

    // Validate the target reviewer exists in the same tenant and has an allowed role.
    CMUserRepository *userRepo = [[CMUserRepository alloc] initWithContext:self.context];
    NSError *lookupErr = nil;
    CMUserAccount *targetUser = [userRepo findByUserId:reviewerId error:&lookupErr];
    if (!targetUser) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Reviewer '%@' not found in the current tenant",
                                             [CMDebugLogger redact:reviewerId]]];
        }
        return NO;
    }

    // The assigned reviewer must have reviewer, finance, or admin role.
    if (![targetUser.role isEqualToString:CMUserRoleReviewer] &&
        ![targetUser.role isEqualToString:CMUserRoleFinance] &&
        ![targetUser.role isEqualToString:CMUserRoleAdmin]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"User '%@' does not have a reviewer-eligible role (has '%@')",
                                             [CMDebugLogger redact:reviewerId], targetUser.role]];
        }
        return NO;
    }

    NSDictionary *beforeJSON = [self snapshotForAppeal:appeal];

    NSString *previousReviewer = appeal.assignedReviewerId;
    appeal.assignedReviewerId = reviewerId;
    appeal.updatedAt = [NSDate date];

    NSDictionary *afterJSON = [self snapshotForAppeal:appeal];

    // Write audit entry.
    NSString *reason;
    if (previousReviewer) {
        reason = [NSString stringWithFormat:@"Reviewer reassigned from %@ to %@",
                  previousReviewer, reviewerId];
    } else {
        reason = [NSString stringWithFormat:@"Reviewer assigned: %@", reviewerId];
    }

    [[CMAuditService shared] recordAction:@"appeal.assign_reviewer"
                               targetType:@"Appeal"
                                 targetId:appeal.appealId
                               beforeJSON:beforeJSON
                                afterJSON:afterJSON
                                   reason:reason
                               completion:nil];

    CMLogInfo(@"appeals.service", @"Assigned reviewer %@ to appeal %@",
              [CMDebugLogger redact:reviewerId], [CMDebugLogger redact:appeal.appealId]);

    // Persist to store.
    NSError *saveErr = nil;
    if (![self.context save:&saveErr]) {
        if (error) { *error = saveErr; }
        return NO;
    }

    return YES;
}

#pragma mark - Submit Decision

- (BOOL)submitDecision:(NSString *)decision
                appeal:(CMAppeal *)appeal
           afterScores:(NSDictionary *)afterScores
                 notes:(NSString *)notes
                 error:(NSError **)error {
    NSParameterAssert(decision.length > 0);
    NSParameterAssert(appeal);
    NSParameterAssert(notes.length > 0);

    // 1. Validate decision value.
    if (![self isValidDecision:decision]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:[NSString stringWithFormat:
                                             @"Invalid decision '%@'; must be uphold, adjust, or reject",
                                             decision]];
        }
        return NO;
    }

    // 2. Cannot decide on an already decided appeal.
    if (appeal.decision) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Appeal already has a decision"];
        }
        return NO;
    }

    // 3. Must have an assigned reviewer.
    if (!appeal.assignedReviewerId) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Appeal must have an assigned reviewer before a decision can be submitted"];
        }
        return NO;
    }

    // 4. Validate current user is authenticated and has reviewer or finance role.
    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"No authenticated user for decision submission"];
        }
        return NO;
    }

    // 4a. Permission check via centralized RBAC matrix.
    if (![tc.currentRole isEqualToString:CMUserRoleAdmin] &&
        ![[CMPermissionMatrix shared] hasPermission:@"appeals.decide" forRole:tc.currentRole]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Current role does not have appeals.decide permission"];
        }
        return NO;
    }

    // 4b. Validate current user is the assigned reviewer.
    if (![tc.currentUserId isEqualToString:appeal.assignedReviewerId]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Only the assigned reviewer can submit a decision"];
        }
        return NO;
    }

    // 5. If monetaryImpact, require Finance role for decision.
    if (appeal.monetaryImpact) {
        if (![tc.currentRole isEqualToString:CMUserRoleFinance]) {
            if (error) {
                *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                        message:@"Finance role required for decisions on appeals with monetary impact"];
            }
            return NO;
        }
    }

    // 6. For "adjust" decision, afterScores is required.
    if ([decision isEqualToString:CMAppealDecisionAdjust] && !afterScores) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"afterScores is required for 'adjust' decision"];
        }
        return NO;
    }

    // 7. Record the decision.
    NSDictionary *beforeJSON = [self snapshotForAppeal:appeal];

    appeal.decision       = decision;
    appeal.decidedBy      = tc.currentUserId;
    appeal.decidedAt      = [NSDate date];
    appeal.decisionNotes  = notes;
    appeal.updatedAt      = [NSDate date];

    if (afterScores) {
        appeal.afterScoreSnapshotJSON = afterScores;
    }

    NSDictionary *afterJSON = [self snapshotForAppeal:appeal];

    // 8. Write audit entry.
    [[CMAuditService shared] recordAction:@"appeal.decide"
                               targetType:@"Appeal"
                                 targetId:appeal.appealId
                               beforeJSON:beforeJSON
                                afterJSON:afterJSON
                                   reason:[NSString stringWithFormat:
                                           @"Decision: %@ — %@", decision, notes]
                               completion:nil];

    CMLogInfo(@"appeals.service", @"Decision submitted for appeal %@: %@",
              [CMDebugLogger redact:appeal.appealId], decision);

    // Persist to store.
    NSError *saveErr = nil;
    if (![self.context save:&saveErr]) {
        if (error) { *error = saveErr; }
        return NO;
    }

    return YES;
}

#pragma mark - Close Appeal

- (BOOL)closeAppeal:(CMAppeal *)appeal
         resolution:(NSString *)resolution
              error:(NSError **)error {
    NSParameterAssert(appeal);
    NSParameterAssert(resolution.length > 0);

    // 1. Must have a decision before closing.
    if (!appeal.decision) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodeValidationFailed
                                    message:@"Cannot close an appeal without a decision"];
        }
        return NO;
    }

    // 2. Role check: only reviewers, finance, and admins may close appeals.
    CMTenantContext *tc = [CMTenantContext shared];
    if (![tc isAuthenticated]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"No authenticated user for closing appeal"];
        }
        return NO;
    }

    if (![tc.currentRole isEqualToString:CMUserRoleAdmin] &&
        ![[CMPermissionMatrix shared] hasPermission:@"appeals.close" forRole:tc.currentRole]) {
        if (error) {
            *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                    message:@"Current role does not have appeals.close permission"];
        }
        return NO;
    }

    // 2b. If monetaryImpact, require Finance role specifically.
    if (appeal.monetaryImpact) {
        if (![tc.currentRole isEqualToString:CMUserRoleFinance]) {
            if (error) {
                *error = [CMError errorWithCode:CMErrorCodePermissionDenied
                                        message:@"Finance role required to close appeals with monetary impact"];
            }
            return NO;
        }
    }

    NSDictionary *beforeJSON = [self snapshotForAppeal:appeal];

    appeal.updatedAt = [NSDate date];

    // 3. Update the linked dispute if any.
    if (appeal.disputeId) {
        CMDisputeRepository *disputeRepo = [[CMDisputeRepository alloc] initWithContext:self.context];
        NSError *disputeErr = nil;
        CMDispute *dispute = [disputeRepo findById:appeal.disputeId error:&disputeErr];
        if (dispute) {
            dispute.resolution = resolution;
            dispute.closedAt   = [NSDate date];
            dispute.updatedAt  = [NSDate date];

            // Set dispute status based on appeal decision.
            if ([appeal.decision isEqualToString:CMAppealDecisionUphold] ||
                [appeal.decision isEqualToString:CMAppealDecisionAdjust]) {
                dispute.status = CMDisputeStatusResolved;
            } else {
                dispute.status = CMDisputeStatusRejected;
            }

            // Audit for dispute status change.
            [[CMAuditService shared] recordAction:@"dispute.resolve"
                                       targetType:@"Dispute"
                                         targetId:dispute.disputeId
                                       beforeJSON:nil
                                        afterJSON:@{
                                            @"status":     dispute.status,
                                            @"resolution": resolution,
                                            @"closedAt":   [dispute.closedAt description]
                                        }
                                           reason:[NSString stringWithFormat:
                                                   @"Dispute closed via appeal %@ (decision: %@)",
                                                   appeal.appealId, appeal.decision]
                                       completion:nil];
        } else {
            CMLogWarn(@"appeals.service", @"Linked dispute %@ not found: %@",
                      [CMDebugLogger redact:appeal.disputeId], disputeErr.localizedDescription);
        }
    }

    NSDictionary *afterJSON = [self snapshotForAppeal:appeal];

    // 4. Write audit entry for appeal closure.
    [[CMAuditService shared] recordAction:@"appeal.close"
                               targetType:@"Appeal"
                                 targetId:appeal.appealId
                               beforeJSON:beforeJSON
                                afterJSON:afterJSON
                                   reason:[NSString stringWithFormat:
                                           @"Appeal closed with resolution: %@", resolution]
                               completion:nil];

    CMLogInfo(@"appeals.service", @"Closed appeal %@ (dispute: %@)",
              [CMDebugLogger redact:appeal.appealId],
              appeal.disputeId ? [CMDebugLogger redact:appeal.disputeId] : @"none");

    // Persist to store.
    NSError *saveErr = nil;
    if (![self.context save:&saveErr]) {
        if (error) { *error = saveErr; }
        return NO;
    }

    return YES;
}

#pragma mark - Private Helpers

- (BOOL)isValidDecision:(NSString *)decision {
    return [decision isEqualToString:CMAppealDecisionUphold] ||
           [decision isEqualToString:CMAppealDecisionAdjust] ||
           [decision isEqualToString:CMAppealDecisionReject];
}

/// Creates a snapshot dictionary of the scorecard for embedding in appeal snapshots.
- (NSDictionary *)snapshotForScorecard:(CMDeliveryScorecard *)scorecard {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"scorecardId"]   = scorecard.scorecardId ?: @"";
    snapshot[@"orderId"]       = scorecard.orderId ?: @"";
    snapshot[@"courierId"]     = scorecard.courierId ?: @"";
    snapshot[@"rubricId"]      = scorecard.rubricId ?: @"";
    snapshot[@"rubricVersion"] = @(scorecard.rubricVersion);
    snapshot[@"totalPoints"]   = @(scorecard.totalPoints);
    snapshot[@"maxPoints"]     = @(scorecard.maxPoints);

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

/// Creates a snapshot dictionary of an appeal's current state.
- (NSDictionary *)snapshotForAppeal:(CMAppeal *)appeal {
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    snapshot[@"appealId"]    = appeal.appealId ?: @"";
    snapshot[@"scorecardId"] = appeal.scorecardId ?: @"";
    snapshot[@"reason"]      = appeal.reason ?: @"";
    snapshot[@"openedBy"]    = appeal.openedBy ?: @"";

    if (appeal.openedAt) {
        snapshot[@"openedAt"] = [appeal.openedAt description];
    }
    if (appeal.disputeId) {
        snapshot[@"disputeId"] = appeal.disputeId;
    }
    if (appeal.assignedReviewerId) {
        snapshot[@"assignedReviewerId"] = appeal.assignedReviewerId;
    }
    if (appeal.decision) {
        snapshot[@"decision"] = appeal.decision;
    }
    if (appeal.decidedBy) {
        snapshot[@"decidedBy"] = appeal.decidedBy;
    }
    if (appeal.decidedAt) {
        snapshot[@"decidedAt"] = [appeal.decidedAt description];
    }
    if (appeal.decisionNotes) {
        snapshot[@"decisionNotes"] = appeal.decisionNotes;
    }
    snapshot[@"monetaryImpact"] = @(appeal.monetaryImpact);

    if (appeal.beforeScoreSnapshotJSON) {
        snapshot[@"beforeScoreSnapshot"] = appeal.beforeScoreSnapshotJSON;
    }
    if (appeal.afterScoreSnapshotJSON) {
        snapshot[@"afterScoreSnapshot"] = appeal.afterScoreSnapshotJSON;
    }

    return [snapshot copy];
}

@end
