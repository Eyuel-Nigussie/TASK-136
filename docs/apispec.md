# CourierMatch iOS — Internal Service API Specification

## 1. General Information

- **Platform**: iOS (iPhone + iPad), native Objective-C / UIKit
- **Deployment**: Fully offline, standalone, on-device
- **Networking**: None. There are no HTTP endpoints, REST APIs, or server connections.
- **Authentication**: Local-only via `CMAuthService`. Sessions managed by `CMSessionManager` with 15-minute idle timeout.
- **Multi-tenancy**: Every data operation is scoped by `tenantId` via `CMTenantContext`.
- **Authorization**: Role-based via `CMPermissionMatrix` loaded from `PermissionMatrix.plist`. Object-level checks enforced in service and UI layers.
- **Persistence**: Core Data (on-device SQLite) with dual-store split protection. Sensitive fields encrypted via AES-256-CBC + HMAC-SHA256.
- **Error domain**: `com.eaglepoint.couriermatch.error` — see `CMErrorCodes.h` for all codes.

### Roles

| Role | Constant | Description |
|---|---|---|
| Courier | `courier` | Creates itineraries, views matches, updates delivery status |
| Dispatcher | `dispatcher` | Triages orders, assigns couriers, overrides matches |
| Reviewer | `reviewer` | Grades manual rubric items, decides appeals |
| Customer Service | `cs` | Manages order notes, opens disputes |
| Finance | `finance` | Reviews monetary adjustments, closes appeals |
| Admin | `admin` | Manages users, tenants, rubrics, forced logout |

---

## 2. Authentication Module

### CMAuthService (singleton)

#### Signup
```objc
- (void)signupWithTenantId:(NSString *)tenantId
                   username:(NSString *)username
                   password:(NSString *)password
                displayName:(nullable NSString *)displayName
                       role:(NSString *)role
                 completion:(void (^)(CMUserAccount *, NSError *))completion;
```
- **Security**: Self-service signup restricted to `courier` role. Non-courier roles require authenticated admin session.
- **Validation**: Password must pass `CMPasswordPolicy` (12+ chars, 1 digit, 1 symbol, not blocklisted). Username must be unique per tenant (case-insensitive).
- **Hashing**: PBKDF2-SHA512 @ 600,000 iterations + 32-byte Keychain pepper.
- **Errors**: `CMErrorCodePasswordPolicyViolation` (2001), `CMErrorCodeUniqueConstraintViolated` (1005), `CMErrorCodePermissionDenied` (5004).

#### Login (password)
```objc
- (void)loginWithTenantId:(NSString *)tenantId
                  username:(NSString *)username
                  password:(NSString *)password
         captchaChallengeId:(nullable NSString *)captchaChallengeId
              captchaAnswer:(nullable NSString *)captchaAnswer
                 completion:(void (^)(CMAuthAttemptResult *))completion;
```
- **Outcomes** (`CMAuthStepOutcome`):
  - `Succeeded` (0) — session opened, `CMTenantContext` populated.
  - `Failed` (1) — invalid credentials.
  - `Locked` (2) — account locked (5 failures -> 10 min lock).
  - `CaptchaRequired` (3) — CAPTCHA needed (3+ failures). `result.pendingCaptcha` contains the challenge.
  - `CaptchaFailed` (4) — wrong CAPTCHA answer. New challenge in `result.pendingCaptcha`.
- **Side effects**: Increments `failedAttempts` on failure. Records `CMLoginHistory` entry. On success: resets counters, opens session.

#### Login (biometric)
```objc
- (void)loginWithBiometricsForUserId:(NSString *)userId
                           completion:(void (^)(CMAuthAttemptResult *))completion;
```
- **Prerequisite**: User must have enrolled biometrics via `CMBiometricEnrollment`.
- **Flow**: Evaluates `LAPolicyDeviceOwnerAuthenticationWithBiometrics`, retrieves Keychain session token, opens session.

#### Re-auth for destructive actions
```objc
- (void)reauthForDestructiveActionWithReason:(NSString *)reason
                                   completion:(void (^)(BOOL success, NSError *))completion;
```
- **Policy**: `LAPolicyDeviceOwnerAuthentication` (biometric + passcode fallback).
- **Required before**: Account deletion, sensitive data unmask, unsigned export.

### CMBiometricEnrollment

#### Enroll biometrics
```objc
+ (void)enrollBiometricsForUser:(CMUserAccount *)user
                      completion:(void (^)(BOOL success, NSError *))completion;
```
- Evaluates biometric policy, generates 32-byte random token, writes to Keychain at `cm.auth.session.<userId>`, sets `user.biometricEnabled = YES`.

### CMSessionManager (singleton)

| Property / Method | Description |
|---|---|
| `hasActiveSession` | `BOOL` — YES if session is open |
| `currentSessionId` | UUID string of current session |
| `issuedAt` / `lastActivityAt` | Session timestamps |
| `openSessionForUser:` | Opens session, starts 30s heartbeat |
| `recordActivity` | Resets idle timer (called from root window gesture) |
| `logout` | Voluntary teardown, clears `CMTenantContext` |
| `preflightSensitiveActionWithError:` | Synchronous check: session valid + no forced logout. Tears down on failure. |
| `handleSceneDidBecomeActive` | Re-evaluates session on foreground |
| `handleSceneDidEnterBackground` | Starts 30s background grace window |

**Notifications**:
- `CMSessionDidOpenNotification`
- `CMSessionDidExpireNotification` (15 min idle)
- `CMSessionDidForceLogoutNotification` (admin set `forceLogoutAt`)

### CMPasswordPolicy (singleton)

```objc
- (CMPasswordViolation)evaluate:(NSString *)password;
- (NSString *)summaryForViolations:(CMPasswordViolation)violations;
```
- **Rules**: 12+ chars, 1 digit, 1 symbol, not in embedded blocklist.
- **Violations** (bitmask): `TooShort`, `MissingDigit`, `MissingSymbol`, `Blocklisted`, `Empty`.

### CMLockoutPolicy (class methods)

```objc
+ (void)applyFailureTo:(CMUserAccount *)user;     // Increments counter; locks at 5
+ (void)applySuccessTo:(CMUserAccount *)user;      // Resets counter
+ (BOOL)maybeClearExpiredLockOn:(CMUserAccount *)user; // Auto-unlock after 10 min
```

### CMCaptchaService (singleton)

```objc
- (CMCaptchaChallenge *)issueChallenge;
- (BOOL)verifyChallengeId:(NSString *)challengeId answer:(NSString *)answer;
```
- Arithmetic CAPTCHA (addition/multiplication). In-memory only, 60s TTL, single-use.
- HMAC-SHA256 verification with per-challenge nonce (never persisted).

---

## 3. Itinerary Module

### CMItineraryRepository

```objc
- (CMItinerary *)insertItinerary;
- (nullable CMItinerary *)findById:(NSString *)itineraryId error:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeItineraries:(NSError **)error;
- (nullable NSArray<CMItinerary *> *)activeForCourierId:(NSString *)courierId error:(NSError **)error;
```

### CMItineraryImporter

```objc
- (void)importFromURL:(NSURL *)fileURL
            completion:(void (^)(NSArray<CMItinerary *> *, NSError *))completion;
```
- **Formats**: CSV, JSON (detected by file extension).
- **Hardening** (Q12): 2 MB file limit, 10,000 row cap, 512-char field limit, BOM stripping, formula injection neutralization (`=`, `+`, `-`, `@` prefixes).
- **Validation**: Addresses normalized via `CMAddressNormalizer`. Invalid rows collected in `error.userInfo[CMItineraryImporterRejectedRowsKey]`.

### CMLocationPrefill

```objc
- (void)requestPrefillWithCompletion:(void (^)(NSString *city, NSString *state, NSString *zip, NSError *))completion;
- (void)cancel;
```
- Uses `kCLLocationAccuracyReduced`. Stops updates after one fix.
- Stops on `UIApplicationDidEnterBackgroundNotification`.
- Prefills city/state/ZIP only (line1 left blank per Q14).

---

## 4. Order Module

### CMOrderRepository

```objc
- (CMOrder *)insertOrder;
- (nullable CMOrder *)findByOrderId:(NSString *)orderId error:(NSError **)error;
- (nullable CMOrder *)findByExternalRef:(NSString *)ref error:(NSError **)error;
- (nullable NSArray<CMOrder *> *)ordersWithStatus:(NSString *)status limit:(NSUInteger)limit error:(NSError **)error;
- (nullable NSArray<CMOrder *> *)candidateOrdersForWindowStart:(NSDate *)start windowEnd:(NSDate *)end limit:(NSUInteger)limit error:(NSError **)error;
```

**Order statuses**: `new`, `assigned`, `picked_up`, `delivered`, `disputed`, `cancelled`.

**Uniqueness constraint**: `(tenantId, externalOrderRef)`.

**Object-level authorization**: Couriers see only orders where `assignedCourierId == currentUserId` OR `status == "new"`.

---

## 5. Match Engine

### CMMatchEngine (singleton)

#### Recompute candidates
```objc
- (void)recomputeCandidatesForItinerary:(CMItinerary *)itinerary
                             completion:(void (^)(NSError *))completion;
```
- **Pipeline**: temporal pre-filter (+-24h) -> spatial bounding box -> hard filters -> scoring -> deterministic sort -> 500-cap truncation -> persist.
- **Scoring formula**: `score = w_time * timeFit + w_detour * detourScore + w_capacity * capacityScore + w_vehicle * vehicleScore`
- **Default weights**: time=30, detour=20, capacity=15, vehicle=10. Configurable per tenant via `configJSON`.
- **Hard filters**: detour > 8 mi, overlap < 20 min, capacity exceeded, vehicle mismatch, terminal status.
- **Detour**: Great-circle with urban multiplier (1.35 metro / 1.15 rural) per Q2.
- **Time fit**: ETA-based overlap with vehicle-type speeds per Q3.
- **Yields**: Skips computation when `thermalState >= serious` or `isLowPowerModeEnabled` (Q5).
- **Truncation**: `CMErrorCodeMatchCandidateTruncated` (5005) when > 500 candidates.

#### Staleness check
```objc
- (BOOL)isCandidateStale:(CMMatchCandidate *)candidate;
```
- Checks `computedAt` age against configurable threshold (default 300s) and `stale` flag.

#### Rank candidates (read path)
```objc
- (nullable NSArray<CMMatchCandidate *> *)rankCandidatesForItinerary:(NSString *)itineraryId error:(NSError **)error;
```
- Returns sorted candidates with persisted `rankPosition` (1-based).
- **Sort order** (Q4): score DESC, detourMiles ASC, pickupWindowStart ASC, orderId ASC.

**Notifications**:
- `CMMatchEngineDidRecomputeNotification` — userInfo: `{ itineraryId }`
- `CMMatchEngineTruncatedNotification` — userInfo: `{ itineraryId, totalBeforeCap }`

**Explanation components**: Each candidate carries `explanationComponents` array of `{ label, delta }` dicts. Rendered via:
```objc
+ (NSString *)summaryStringFromComponents:(NSArray *)components;
// Output: "+30.0 time fit, +20.0 detour, -15.0 capacity risk"
```

---

## 6. Notification Module

### CMNotificationCenterService

#### Emit notification
```objc
- (void)emitNotificationForEvent:(NSString *)templateKey
                         payload:(nullable NSDictionary *)payload
                 recipientUserId:(NSString *)recipientUserId
               subjectEntityType:(nullable NSString *)subjectEntityType
                 subjectEntityId:(nullable NSString *)subjectEntityId
                      completion:(nullable void (^)(CMNotificationItem *, NSError *))completion;
```
- **Template keys**: `assigned`, `picked_up`, `delivered`, `dispute_opened`.
- **Payload variables**: `orderRef`, `courierName`, `pickupTime`, `deliveredTime`, `reason`, `count`. Missing variables render as `[n/a]`.
- **Rate limiting** (Q6): Max 5 per minute per `(tenantId, templateKey)`. Excess items get `status = coalesced`; a `digest` notification aggregates `childIds`.
- **In-app only**: No system notifications, no push.

#### Read / Acknowledge
```objc
- (BOOL)markRead:(NSString *)notificationId error:(NSError **)error;
- (BOOL)markAcknowledged:(NSString *)notificationId error:(NSError **)error;
```
- Sets `readAt` / `ackedAt`. Digest cascades to all children.
- **Recipient authorization**: Only the `recipientUserId` can mark their own notifications.

#### Queries
```objc
- (NSUInteger)unreadCountForCurrentUser;
- (nullable NSArray<CMNotificationItem *> *)unreadNotificationsForCurrentUser:(NSUInteger)limit error:(NSError **)error;
```

**Notification**: `CMNotificationUnreadCountDidChangeNotification`.

---

## 7. Scoring Module

### CMScoringEngine

#### Create scorecard
```objc
- (nullable CMDeliveryScorecard *)createScorecardForOrder:(CMOrder *)order
                                                courierId:(NSString *)courierId
                                                    error:(NSError **)error;
```
- Creates scorecard locked to current `rubricId` + `rubricVersion` (Q18).
- Runs all automatic evaluators via `CMAutoScorerRegistry`.

#### Automatic evaluators

| Key | Logic | Points |
|---|---|---|
| `on_time_within_10min` | `updatedAt` within 10 min of `dropoffWindowEnd` and status is `delivered` | Full or 0 |
| `photo_attached` | At least one `image/*` attachment for the order | Full or 0 |
| `signature_captured` | Attachment with `ownerType == "signature"` | Full or 0 |

#### Check rubric upgrade (Q18)
```objc
- (NSDictionary *)checkRubricUpgradeAvailable:(CMDeliveryScorecard *)scorecard;
```
- Returns `{ upgradeAvailable: BOOL, latestVersion: int64, latestRubricId: string }`.

#### Upgrade rubric (Q18)
```objc
- (nullable CMDeliveryScorecard *)upgradeScorecardRubric:(CMDeliveryScorecard *)scorecard error:(NSError **)error;
```
- Creates new scorecard with `supersedesScorecardId`, re-runs auto-scorers, writes `scorecard.rubric_upgraded` audit entry.

#### Record manual grade
```objc
- (BOOL)recordManualGrade:(CMDeliveryScorecard *)scorecard
                   itemKey:(NSString *)itemKey
                    points:(double)points
                     notes:(NSString *)notes
                     error:(NSError **)error;
```
- **Validation**: `0 <= points <= maxPoints`. Notes mandatory when `points < maxPoints / 2`.
- **Error**: `CMErrorCodeValidationFailed` (5001) on bounds violation.

#### Finalize scorecard
```objc
- (BOOL)finalizeScorecard:(CMDeliveryScorecard *)scorecard error:(NSError **)error;
```
- **Prerequisite**: All rubric items must have results. Session preflight required.
- Sets `finalizedAt`, `finalizedBy`, computes `totalPoints` / `maxPoints`.
- Writes `scorecard.finalize` audit entry with before/after snapshots.
- **Immutable** after finalization. Changes require an Appeal.
- **Error**: `CMErrorCodeScorecardAlreadyFinalized` (5003).

---

## 8. Appeals Module

### CMAppealService

#### Open appeal
```objc
- (nullable CMAppeal *)openAppeal:(nullable CMDispute *)dispute
                        scorecard:(CMDeliveryScorecard *)scorecard
                           reason:(NSString *)reason
                            error:(NSError **)error;
```
- **Prerequisite**: Scorecard must be finalized.
- Captures `beforeScoreSnapshotJSON` (locked).
- Links to dispute if provided. Writes `appeal.open` audit entry.

#### Assign reviewer
```objc
- (BOOL)assignReviewer:(NSString *)reviewerId
              toAppeal:(CMAppeal *)appeal
                 error:(NSError **)error;
```
- Writes `appeal.assign_reviewer` audit entry with before/after.

#### Submit decision
```objc
- (BOOL)submitDecision:(NSString *)decision
                appeal:(CMAppeal *)appeal
           afterScores:(nullable NSDictionary *)afterScores
                 notes:(NSString *)notes
                 error:(NSError **)error;
```
- **Decisions**: `uphold`, `adjust`, `reject`.
- **Validation**: Current user must be the assigned reviewer. `afterScores` required for `adjust`. Finance role required when `monetaryImpact == YES`.
- Writes `appeal.decide` audit entry.

#### Close appeal
```objc
- (BOOL)closeAppeal:(CMAppeal *)appeal
          resolution:(NSString *)resolution
               error:(NSError **)error;
```
- **Finance gate**: Finance role required when `monetaryImpact == YES`.
- Updates linked dispute status (`resolved` or `rejected`). Writes `appeal.close` + `dispute.resolve` audit entries.

---

## 9. Audit Module

### CMAuditService (singleton)

#### Record action (async)
```objc
- (void)recordAction:(NSString *)action
          targetType:(nullable NSString *)targetType
            targetId:(nullable NSString *)targetId
          beforeJSON:(nullable NSDictionary *)beforeJSON
           afterJSON:(nullable NSDictionary *)afterJSON
              reason:(nullable NSString *)reason
          completion:(nullable void (^)(CMAuditEntry *, NSError *))completion;
```
- **Append-only**: Entries are never updated or deleted.
- **Hash chain**: `entryHash = HMAC-SHA256(tenantSeed, prevHash || canonicalJSON(entry))`.
- **Meta-chain** (Q8): Device-wide chain records every tenant chain head update. Non-deletable.

#### Record action (synchronous)
```objc
- (nullable CMAuditEntry *)recordActionSync:(NSString *)action
                                 targetType:(nullable NSString *)targetType
                                   targetId:(nullable NSString *)targetId
                                 beforeJSON:(nullable NSDictionary *)beforeJSON
                                  afterJSON:(nullable NSDictionary *)afterJSON
                                     reason:(nullable NSString *)reason
                                    context:(NSManagedObjectContext *)context
                                      error:(NSError **)error;
```

#### Record permission change
```objc
- (void)recordPermissionChangeForSubject:(NSString *)subjectUserId
                                 oldRole:(NSString *)oldRole
                                 newRole:(NSString *)newRole
                                  reason:(nullable NSString *)reason
                              completion:(nullable void (^)(CMAuditEntry *, NSError *))completion;
```

**Common audit actions**: `order.assign`, `order.notes_edited`, `scorecard.create`, `scorecard.finalize`, `scorecard.rubric_upgraded`, `scorecard.manual_grade`, `appeal.open`, `appeal.assign_reviewer`, `appeal.decide`, `appeal.close`, `dispute.resolve`, `permission.role_changed`, `permission.granted`, `permission.revoked`, `sensitive.unmask_viewed`, `attachment.reject`, `attachment.tamper_suspected`, `notification.created`, `notification.read`, `notification.ack`, `export.initiated`.

### CMAuditVerifier (singleton)

```objc
- (void)verifyChainForTenant:(NSString *)tenantId
                    progress:(void (^)(NSUInteger verified, NSUInteger total))progress
                  completion:(void (^)(BOOL valid, NSString *brokenEntryId, NSError *))completion;
```
- Walks entries chronologically, recomputes hashes. Resumes from `CMWorkAuditCursor`.
- **Error**: `CMErrorCodeAuditChainBroken` (7001) with broken entry ID.

### CMPermissionChangeAuditor (singleton)

```objc
- (void)recordRoleChange:(NSString *)subjectUserId oldRole:(NSString *)oldRole newRole:(NSString *)newRole reason:(NSString *)reason completion:(void (^)(CMAuditEntry *, NSError *))completion;
- (void)recordPermissionGrant:(NSString *)subjectUserId permission:(NSString *)permission reason:(NSString *)reason completion:...;
- (void)recordPermissionRevoke:(NSString *)subjectUserId permission:(NSString *)permission reason:(NSString *)reason completion:...;
- (void)recordPermissionBulkUpdate:(NSString *)subjectUserId oldPerms:(NSArray *)old newPerms:(NSArray *)new reason:(NSString *)reason completion:...;
```

---

## 10. Attachments Module

### CMAttachmentService (singleton)

#### Save attachment
```objc
- (void)saveAttachmentWithFilename:(NSString *)filename
                              data:(NSData *)data
                          mimeType:(NSString *)mimeType
                         ownerType:(NSString *)ownerType
                           ownerId:(NSString *)ownerId
                        completion:(void (^)(CMAttachment *, NSError *))completion;
```
- **Validation**: MIME + magic-byte match required. Allowlist: `image/jpeg`, `image/png`, `application/pdf`. Max 10 MB.
- **Storage**: `Documents/attachments/{tenantId}/{uuid}.{ext}`, `NSFileProtectionCompleteUnlessOpen`.
- **Hashing** (Q13): SHA-256 computed off-main via `NSOperationQueue`. `hashStatus` transitions: `pending` -> `ready`.
- **Expiry**: `expiresAt = capturedAt + 30 days`.
- **Errors**: `CMErrorCodeAttachmentTooLarge` (4001), `CMErrorCodeAttachmentMimeNotAllowed` (4002), `CMErrorCodeAttachmentMagicMismatch` (4003).

#### Load attachment
```objc
- (nullable NSData *)loadAttachment:(CMAttachment *)attachment error:(NSError **)error;
```
- Re-validates SHA-256 hash on read. Mismatch -> `hashStatus = tampered` + `attachment.tamper_suspected` audit entry.

#### Delete attachment
```objc
- (BOOL)deleteAttachment:(CMAttachment *)attachment error:(NSError **)error;
```

#### Generate thumbnail
```objc
- (void)generateThumbnail:(CMAttachment *)attachment
                completion:(void (^)(UIImage *))completion;
```
- Off-main generation. Three-tier cache: memory (NSCache) -> disk (`Caches/attachment-thumbs/`) -> regenerate.
- Flushed on `CMMemoryPressureNotification`.

### CMAttachmentAllowlist (singleton)

```objc
- (BOOL)validateData:(NSData *)data mimeType:(NSString *)mimeType error:(NSError **)error;
- (nullable NSString *)mimeTypeFromMagicBytes:(NSData *)data;
```
- **Magic bytes**: JPEG (`FF D8 FF`), PNG (`89 50 4E 47`), PDF (`%PDF`).

---

## 11. Admin Module

### CMPermissionMatrix (singleton)

```objc
- (BOOL)hasPermission:(NSString *)action forRole:(NSString *)role;
- (NSArray<NSString *> *)allowedActionsForRole:(NSString *)role;
```

**Permission map** (from `PermissionMatrix.plist`):

| Role | Permissions |
|---|---|
| courier | `itineraries.create`, `itineraries.edit_own`, `orders.view_assigned`, `orders.accept_match`, `orders.update_status_own`, `attachments.upload_own`, `notifications.read_own` |
| dispatcher | `orders.view_all`, `orders.assign`, `orders.override_match`, `itineraries.view_all`, `notifications.read_all` |
| reviewer | `disputes.view`, `appeals.grade_manual`, `appeals.decide`, `scorecards.view` |
| cs | `orders.view_all`, `orders.edit_notes`, `disputes.open`, `attachments.upload_dispute` |
| finance | `appeals.close_monetary`, `appeals.view`, `exports.finance` |
| admin | `tenants.manage`, `users.manage`, `users.role_change`, `users.force_logout`, `users.physical_purge`, `rubrics.publish`, `allowlists.configure`, `diagnostics.view`, `audit.verify` |

---

## 12. Persistence Layer

### CMTenantContext (singleton)

```objc
- (void)setUserId:(NSString *)userId tenantId:(NSString *)tenantId role:(NSString *)role;
- (void)clear;
- (BOOL)isAuthenticated;
- (nullable NSPredicate *)scopingPredicate;  // "tenantId == %@ AND deletedAt == nil"
```
- **Notification**: `CMTenantContextDidChangeNotification`.

### CMRepository (base class)

```objc
- (instancetype)initWithContext:(NSManagedObjectContext *)context;
- (NSFetchRequest *)scopedFetchRequest;
- (nullable NSArray *)fetchWithPredicate:(nullable NSPredicate *)predicate
                          sortDescriptors:(nullable NSArray *)sorts
                                    limit:(NSUInteger)limit
                                    error:(NSError **)error;
- (nullable id)fetchOneWithPredicate:(nullable NSPredicate *)predicate error:(NSError **)error;
- (__kindof NSManagedObject *)insertStampedObject;
```
- **Tenant scoping**: Every fetch includes `tenantId == currentTenantId AND deletedAt == nil`.
- **Refuses unscoped queries**: Returns `CMErrorCodeTenantScopingViolation` (1004) when no tenant context is set.
- **Auto-stamps**: `tenantId`, `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version = 1` on insert.

### CMSaveWithVersionCheckPolicy

```objc
+ (CMSaveOutcome)saveChanges:(NSDictionary *)changes
                    toObject:(NSManagedObject *)object
                 baseVersion:(int64_t)baseVersion
                    resolver:(nullable CMFieldConflictResolver)resolver
                mergedFields:(NSArray **)mergedFieldsOut
              conflictFields:(NSArray **)conflictFieldsOut
                       error:(NSError **)error;
```
- **Outcomes**: `Saved`, `AutoMerged` (disjoint fields), `ResolvedAndSaved` (resolver consulted), `Failed`.
- **Conflict resolution** (Q9): Disjoint field changes auto-merge silently. Overlapping fields invoke resolver with `KeepMine` / `KeepTheirs` per field.

### CMIDMasker (class methods)

```objc
+ (NSString *)ssnStyle:(NSString *)value;       // "***-**-1234"
+ (NSString *)emailStyle:(NSString *)value;     // "****@domain.com"
+ (NSString *)phoneStyle:(NSString *)value;     // "(***) ***-12-34"
+ (NSString *)maskTrailing:(NSString *)value visibleTail:(NSUInteger)tail;
```
- Unmask requires biometric re-auth + `sensitive.unmask_viewed` audit entry.

---

## 13. Background Tasks

Registered via `CMBackgroundTaskManager` at launch:

| Identifier | Type | Purpose | Schedule |
|---|---|---|---|
| `com.eaglepoint.couriermatch.match.refresh` | `BGAppRefreshTask` | Recompute stale match candidates | 15 min |
| `com.eaglepoint.couriermatch.attachments.cleanup` | `BGProcessingTask` | Delete expired attachments (30-day) | 6 hours |
| `com.eaglepoint.couriermatch.notifications.purge` | `BGProcessingTask` | Purge old acked notifications | 4 hours |
| `com.eaglepoint.couriermatch.audit.verify` | `BGProcessingTask` | Verify audit hash chain integrity | 12 hours |

All processing tasks: `requiresExternalPower = YES`, `requiresNetworkConnectivity = NO`.
All tasks check `isProtectedDataAvailable` before touching main store (Q7).
All tasks yield on thermal stress / low power mode (Q5).

---

## 14. Error Codes

| Code | Constant | Description |
|---|---|---|
| 1001 | `CMErrorCodeCoreDataBootFailed` | Core Data stack failed to load |
| 1002 | `CMErrorCodeCoreDataSaveFailed` | Core Data save failed |
| 1003 | `CMErrorCodeOptimisticLockConflict` | Version mismatch during save |
| 1004 | `CMErrorCodeTenantScopingViolation` | Fetch attempted without tenant context |
| 1005 | `CMErrorCodeUniqueConstraintViolated` | Duplicate record |
| 2001 | `CMErrorCodePasswordPolicyViolation` | Password doesn't meet policy |
| 2002 | `CMErrorCodeAuthInvalidCredentials` | Wrong username/password |
| 2003 | `CMErrorCodeAuthAccountLocked` | Account locked (5 failures) |
| 2004 | `CMErrorCodeAuthCaptchaRequired` | CAPTCHA needed (3+ failures) |
| 2005 | `CMErrorCodeAuthCaptchaFailed` | Wrong CAPTCHA answer |
| 2006 | `CMErrorCodeAuthSessionExpired` | 15-min idle timeout |
| 2007 | `CMErrorCodeAuthForcedLogout` | Admin revoked session |
| 2008 | `CMErrorCodeBiometricUnavailable` | No biometric hardware/enrollment |
| 3001 | `CMErrorCodeKeychainOperationFailed` | Keychain read/write failed |
| 3002 | `CMErrorCodeCryptoOperationFailed` | Encryption/hashing failed |
| 4001 | `CMErrorCodeAttachmentTooLarge` | File exceeds 10 MB |
| 4002 | `CMErrorCodeAttachmentMimeNotAllowed` | Not in JPG/PNG/PDF allowlist |
| 4003 | `CMErrorCodeAttachmentMagicMismatch` | MIME doesn't match file header |
| 4004 | `CMErrorCodeAttachmentHashMismatch` | SHA-256 tamper detected on read |
| 5001 | `CMErrorCodeValidationFailed` | Generic validation failure |
| 5003 | `CMErrorCodeScorecardAlreadyFinalized` | Cannot modify finalized scorecard |
| 5004 | `CMErrorCodePermissionDenied` | Role lacks required permission |
| 5005 | `CMErrorCodeMatchCandidateTruncated` | Candidates capped at 500 |
| 7001 | `CMErrorCodeAuditChainBroken` | Hash chain integrity violation |
| 7002 | `CMErrorCodeAuditSeedMissing` | Keychain audit seed not found |
