# CourierMatch Operations & Audit — iOS App System Design

**Document version:** 1.0
**Date:** 2026-04-13
**Target platform:** iOS (iPhone + iPad), native
**Language:** Objective-C (no Swift)
**UI Framework:** UIKit (no SwiftUI)
**Deployment model:** Fully offline, standalone, multi-tenant on-device

---

## 1. Overview

CourierMatch is a native iOS operations and audit application used by logistics
teams to perform offline courier dispatching, itinerary-based order matching,
templated notification delivery, and compliant delivery-quality scoring with a
non-editable audit trail.

The app is fully self-contained: all computation (scoring, matching, audit,
notifications, authentication) is performed locally on the device. There are
no APIs, no servers, and no external services. The application nevertheless
supports a strict multi-tenant ("multi-company") boundary where every row of
business data carries a `tenantId` that scopes all queries, uniqueness
constraints, and access checks.

### 1.1 Roles

| Role | Primary responsibilities |
|---|---|
| Courier | Define itineraries (origin/destination/time window/vehicle/on-the-way stops), view ranked eligible orders, accept matches, update delivery status, upload proofs. |
| Operations Dispatcher | Triage incoming orders, resolve conflicts, assign orders manually, override match scores with justification. |
| Reviewer | Perform manual review on disputed deliveries, grade subjective rubric items, author appeal decisions. |
| Customer Service | Manage customer-facing order notes, intake disputes, attach evidence. |
| Finance | Review monetary adjustments arising from disputes and score appeals. |
| Administrator | Configure tenants, rubrics, allowlists, user accounts, permission assignments, forced-logout actions. |

### 1.2 Primary use cases

1. A Courier imports or creates an itinerary. The app returns a ranked list of
   on-the-way orders with an explanation string, auto-filtering conflicts.
2. An Operations Dispatcher inspects an order, views matched couriers, assigns
   one, and the notification center generates a templated "Assigned"
   announcement subject to rate limiting.
3. A Reviewer opens a dispute, pulls the locked snapshot of automated + manual
   rubric scores, records before/after values and a reason, closes the appeal
   producing an append-only audit entry.
4. An Administrator changes a user's role. The permission-change auditor logs
   old/new role, actor, subject, timestamp, and reason.
5. Daily background tasks recompute match rankings against active itineraries
   and purge expired notifications and stale attachments.

### 1.3 Out of scope

- Real-time networking, push notifications, telemetry, third-party analytics.
- SSO, OAuth, email verification, SMS — all external auth methods are
  deliberately disabled in this offline build (extensibility is preserved).
- Server-side audit. All auditing is local, append-only, and hash-chained on
  device.

---

## 2. Architecture

### 2.1 High-level architecture

The app follows a layered, MVVM-ish structure expressed in Objective-C with
UIKit view controllers. Coordinators route between flows; services encapsulate
cross-cutting concerns; repositories mediate Core Data.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation (UIKit)                      │
│  UIViewController subclasses · View Models · Coordinators    │
│       Auto Layout · Safe Area · Dark Mode · Dynamic Type     │
└─────────────────────────────────────────────────────────────┘
                               │
┌─────────────────────────────────────────────────────────────┐
│                       Domain Services                        │
│ AuthService · SessionManager · MatchEngine · ScoringEngine   │
│ NotificationCenterService · AuditService · AppealService     │
│ AttachmentService · TenantContext · FeatureFlags             │
└─────────────────────────────────────────────────────────────┘
                               │
┌─────────────────────────────────────────────────────────────┐
│                     Repository Layer                         │
│  UserRepository · OrderRepository · ItineraryRepository      │
│  NotificationRepository · AuditRepository · AppealRepository │
│  AttachmentRepository · TenantRepository · ConfigRepository  │
└─────────────────────────────────────────────────────────────┘
                               │
┌─────────────────────────────────────────────────────────────┐
│              Persistence & Platform                          │
│  Core Data (encrypted store, NSFileProtectionComplete)       │
│  Keychain (secrets, password verifier, pepper, audit key)    │
│  FileManager sandbox (attachments, thumbnails)               │
│  BackgroundTasks · LocalAuthentication · CoreLocation        │
│  UserNotifications (local-only, in-app center backed)        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Module boundaries

- `CM.App` — application delegate, scene delegate, app-wide coordinators.
- `CM.Auth` — signup, login, lockout, CAPTCHA, biometrics, session timer.
- `CM.Itinerary` — itinerary capture, import, on-the-way stops.
- `CM.Orders` — order CRUD, triage, assignment, conflict detection.
- `CM.Match` — MatchEngine, scoring weights, explanation strings.
- `CM.Notifications` — templated messages, rate limiter, ack tracking.
- `CM.Scoring` — rubric runner, automatic scorers, manual grading UI.
- `CM.Appeals` — dispute intake, reviewer workflow, audit trail.
- `CM.Audit` — append-only audit log, hash chain, permission-change auditor.
- `CM.Attachments` — camera capture, hashing, sandbox storage, cleanup.
- `CM.Admin` — tenants, roles, allowlists, forced logout, config.
- `CM.Common` — masking, date/address normalization, haptics, theming,
  accessibility helpers, error surfaces.

### 2.3 Threading model

- Core Data uses a private-queue `NSPersistentContainer` with a
  `viewContext` on main and a background `NSManagedObjectContext` for writes
  created per write unit via `performBackgroundTask:`.
- `MatchEngine`, `ScoringEngine`, and hash/cleanup jobs run on a dedicated
  `NSOperationQueue` (QoS: utility) to keep the main thread responsive.
- Background tasks (`BGTaskScheduler`) dispatch to the same engines via
  short-lived operations bounded by the system-granted time window.
- UI updates are posted with `dispatch_async(dispatch_get_main_queue(), …)`
  from completion handlers — all `UIViewController` mutations on main.

### 2.4 Navigation

- On iPhone: a `UITabBarController` with role-aware tabs (Itineraries, Orders,
  Notifications, Scoring/Appeals, Admin). Secondary flows push onto a
  per-tab `UINavigationController`.
- On iPad: a `UISplitViewController` (three-column where available) is used.
  Primary = role sidebar, supplementary = list, secondary = detail. The app
  supports Slide Over, Split View multitasking, and both orientations.
- All containers use Auto Layout with `safeAreaLayoutGuide`, `readableContentGuide`
  for long text, and `UITraitCollection` change hooks to react to size class,
  Dynamic Type, and appearance (light/dark) transitions.

---

## 3. Data Model

Persisted in Core Data. Every business entity carries `tenantId` (UUID),
`createdAt`, `updatedAt`, `version` (int64, optimistic lock), and
`createdBy` / `updatedBy` (user UUID). Soft deletes use `deletedAt`.

### 3.1 Core entities

**Tenant**
- `tenantId` (UUID, PK)
- `name` (string)
- `status` (enum: active, suspended)
- `configJSON` (transformable; per-tenant rubric, weights, allowlists, rate limits)

**UserAccount**
- `userId` (UUID, PK)
- `tenantId` (UUID, FK) — users are scoped to a tenant (admin may be global via separate flag)
- `username` (string, unique within tenant, case-insensitive collation)
- `displayName` (string)
- `passwordHash` (binary — Argon2id or PBKDF2-SHA256 with per-user salt + Keychain-stored pepper)
- `passwordSalt` (binary)
- `passwordUpdatedAt` (date)
- `role` (enum: courier, dispatcher, reviewer, cs, finance, admin)
- `status` (enum: active, locked, disabled)
- `failedAttempts` (int16)
- `lockUntil` (date, nullable)
- `biometricEnabled` (bool)
- `biometricRefId` (string — Keychain reference, not the biometric data itself)
- `lastLoginAt` (date)
- `forceLogoutAt` (date, nullable — admin-set sentinel checked on each heartbeat)

**Session** (not persisted across reboots; stored in Keychain-backed blob with file protection)
- `sessionId`, `userId`, `issuedAt`, `lastActivityAt`, `expiresAt` (15 min idle sliding window).

**LoginHistory**
- `entryId`, `userId`, `tenantId`, `deviceModel`, `osVersion`, `appVersion`,
  `loggedInAt`, `loggedOutAt`, `outcome` (success, failed, locked, captcha-gated),
  `ipAddressOrNil` (best-effort local, nullable).

**Itinerary**
- `itineraryId` (UUID, PK), `tenantId`, `courierId` (FK UserAccount)
- `originAddress` (embedded struct below), `destinationAddress`
- `departureWindowStart`, `departureWindowEnd` (date)
- `vehicleType` (enum: bike, car, van, truck)
- `vehicleCapacityVolumeL`, `vehicleCapacityWeightKg`
- `onTheWayStops` (transformable array of Address)
- `status` (enum: draft, active, completed, cancelled)

**Address** (value type, transformable or separate entity)
- `line1`, `line2`, `city`, `stateAbbr` (normalized to USPS 2-letter), `zip` (normalized 5 or 5+4), `lat`, `lng`, `normalizedKey`.

**Order**
- `orderId` (UUID, PK), `tenantId`
- `externalOrderRef` (string — de-dup key; uniqueness constraint on (`tenantId`,`externalOrderRef`))
- `pickupAddress`, `dropoffAddress`
- `pickupWindowStart`, `pickupWindowEnd`, `dropoffWindowStart`, `dropoffWindowEnd`
- `parcelVolumeL`, `parcelWeightKg`, `requiresVehicleType` (nullable enum)
- `status` (enum: new, assigned, picked_up, delivered, disputed, cancelled)
- `assignedCourierId` (FK, nullable)
- `customerNotes` (string)
- `sensitiveCustomerId` (string — displayed masked)

**MatchCandidate** (denormalized, recomputed by MatchEngine)
- `candidateId`, `tenantId`, `itineraryId`, `orderId`
- `score` (double), `detourMiles`, `timeOverlapMinutes`, `capacityRisk`
- `explanationComponents` (transformable ordered list of `{factor, delta, label}`)
- `computedAt` (date), `stale` (bool)

**NotificationItem**
- `notificationId`, `tenantId`, `subjectEntityType`, `subjectEntityId`
- `templateKey` (enum: assigned, picked_up, delivered, dispute_opened, …)
- `payloadJSON` (transformable — resolved variables)
- `renderedTitle`, `renderedBody`
- `recipientUserId`, `createdAt`, `readAt` (nullable), `ackedAt` (nullable)
- `rateLimitBucket` (minute bucket id for local limiter)

**Dispute**
- `disputeId`, `tenantId`, `orderId`, `openedBy`, `openedAt`
- `reason` (string), `status` (open, in_review, resolved, rejected)
- `reviewerId` (nullable), `resolution` (string), `closedAt`

**RubricTemplate**
- `rubricId`, `tenantId`, `name`, `active`, `version`
- `items` (transformable — ordered list of `RubricItem`)

**RubricItem** (value type)
- `itemKey`, `label`, `mode` (automatic, manual)
- `maxPoints`, `autoEvaluator` (enum: on_time_within_10min, photo_attached, signature_captured, custom)
- `instructions`

**DeliveryScorecard**
- `scorecardId`, `tenantId`, `orderId`, `courierId`, `rubricId`, `rubricVersion`
- `automatedResults` (transformable — per-item `{key, points, evidence}`)
- `manualResults` (transformable — per-item `{key, points, grader, notes}`)
- `totalPoints`, `maxPoints`, `finalizedAt`, `finalizedBy`

**Appeal**
- `appealId`, `tenantId`, `scorecardId`, `disputeId` (nullable)
- `reason`, `openedBy`, `openedAt`
- `assignedReviewerId`, `beforeScoreSnapshotJSON`, `afterScoreSnapshotJSON`
- `decision` (uphold, adjust, reject), `decidedBy`, `decidedAt`, `decisionNotes`
- `auditChainHead` (string — hash anchor into AuditEntry chain)

**AuditEntry** (append-only; never updated, never deleted)
- `entryId` (UUID, PK), `tenantId`, `actorUserId`, `actorRole`
- `action` (string — e.g., `order.assign`, `appeal.decide`, `user.role_changed`)
- `targetType`, `targetId`, `beforeJSON` (nullable), `afterJSON` (nullable)
- `reason` (string), `createdAt`
- `prevHash` (bytes), `entryHash` (bytes — SHA-256 over prev + canonical entry bytes + tenant-scoped HMAC key from Keychain)

**Attachment**
- `attachmentId`, `tenantId`, `ownerType`, `ownerId`
- `filename`, `mimeType`, `sizeBytes`, `sha256Hex`
- `capturedAt`, `expiresAt` (capturedAt + 30 days)
- `storagePathRelative` (relative to app Documents)
- `capturedByUserId`

**AttachmentAllowlistEntry** (per-tenant config, also baseline global)
- `mimeType` (e.g., `image/jpeg`, `image/png`, `application/pdf`)
- `maxBytes` (<= 10 MB)

**PermissionChange** (specialized audit view — physically stored as AuditEntry with action prefix `permission.*`, but indexed here)

**CaptchaChallenge** (transient, Core Data, short TTL)
- `challengeId`, `userId`, `question`, `answerHash`, `createdAt`, `expiresAt`.

### 3.2 Uniqueness & indexing

- Unique constraint: (`tenantId`, `externalOrderRef`) on `Order`.
- Unique constraint: (`tenantId`, `username`) on `UserAccount`, case-insensitive.
- Indexes: `Order.status`, `Order.pickupWindowStart`, `Itinerary.departureWindowStart`,
  `NotificationItem.recipientUserId+createdAt`, `AuditEntry.createdAt`,
  `MatchCandidate.itineraryId`, `Attachment.expiresAt`.

### 3.3 Encryption at rest

- Core Data SQLite store is created with
  `NSPersistentStoreFileProtectionKey = NSFileProtectionComplete` so the file
  is unreadable while the device is locked.
- Sensitive fields (`passwordHash`, `auditChainHead`, HMAC key references,
  biometric reference IDs) live in the Keychain with
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- A per-install data-encryption key is generated in the Keychain and used
  to AES-GCM-encrypt specific payload fields (e.g., `sensitiveCustomerId`,
  `customerNotes` when flagged) before Core Data write; ciphertext stored as
  `Data`, IV stored alongside.
- Attachments are saved under `…/Documents/attachments/{tenantId}/…` with
  `NSFileProtectionCompleteUnlessOpen`, enabling background cleanup to access
  them while locked when appropriate.

---

## 4. Authentication, Session, and Access Control

### 4.1 Sign-up / Sign-in

- Local-only, username + password. No network.
- Password rules enforced client-side:
  - Minimum 12 characters
  - At least 1 digit
  - At least 1 symbol from a documented class
  - Rejected against a small embedded common-password blocklist
- Password stored as Argon2id (preferred) or PBKDF2-SHA256 (fallback in pure
  CommonCrypto) with a per-user random salt plus a Keychain-held pepper. Only
  the derived hash is kept in Core Data.
- Failed-attempt policy:
  - 5 consecutive failures → account `locked` with `lockUntil = now + 10 min`.
  - After 3 failures (pre-lock), the next attempt must pass a local CAPTCHA
    (image-distorted text or simple math rendered via Core Graphics). Answer
    validated against `CaptchaChallenge.answerHash`.
- Forced logout: `UserAccount.forceLogoutAt` is compared against
  `Session.issuedAt` on each heartbeat; any session older is invalidated.

### 4.2 Biometrics

- `LocalAuthentication.LAContext` with policy
  `LAPolicyDeviceOwnerAuthenticationWithBiometrics` for Face ID / Touch ID.
- Biometrics never act as a primary secret; they unlock a Keychain item that
  contains the local session re-issue token. Without Face ID/Touch ID the
  user still has a password path.
- Destructive actions (e.g., delete account) must re-prompt biometrics via a
  stricter `LAPolicyDeviceOwnerAuthentication`.

### 4.3 Session timeout

- `SessionManager` tracks `lastActivityAt` via `UIApplication`-level gesture
  and `-touchesBegan:…` hooks on a root view. A timer fires every 30s; if
  `now − lastActivityAt ≥ 15 min`, the session is torn down and the lock
  screen is presented.
- On `applicationDidEnterBackground:`, the app immediately blurs all windows
  and starts a short grace window (e.g., 30s) before requiring re-auth.

### 4.4 Role-based access control

- `TenantContext` holds `(currentUser, currentTenant)`. Every repository call
  must pass the tenant context and filter by `tenantId`.
- A `PermissionMatrix` plist enumerates, per role, allowed actions
  (e.g., `orders.assign`, `rubrics.edit`, `users.role_change`). Controllers
  query `PermissionMatrix hasPermission:forRole:` before presenting actions.
- Role changes are mediated only through `AdminService`, which writes a
  `permission.role_changed` AuditEntry.

### 4.5 Extensibility for other methods

`AuthProvider` protocol exposes `authenticateWithCredentials:…`,
`supportedFactors`, and `isEnabled`. Only `LocalPasswordAuthProvider` and
`BiometricAuthProvider` are registered in this build; OAuth/SAML stubs are
reserved behind a feature flag `kFeatureRemoteAuthEnabled = NO`.

---

## 5. Itinerary & Match Engine

### 5.1 Itinerary capture

- Couriers define origin, destination, departure window, vehicle type,
  optional on-the-way stops.
- Import supports CSV/JSON file picked via `UIDocumentPickerViewController`;
  parser normalizes addresses using the Data Quality rules (§7) before save.
- Optional location prefill: `CLLocationManager` with
  `desiredAccuracy = kCLLocationAccuracyReduced` (also uses
  `requestTemporaryFullAccuracyAuthorization` only when user opts in). Updates
  stop immediately on `applicationDidEnterBackground:`.

### 5.2 Match scoring

For each active itinerary `I` and each candidate order `O` within the same
tenant and not in terminal states (`delivered`, `cancelled`), the engine
computes a composite score:

```
score(I, O) = w_time   * timeFitScore(I, O)
            + w_detour * detourScore(I, O)
            + w_capacity * capacityScore(I, O)
            + w_vehicle  * vehicleScore(I, O)
```

Defaults (admin-configurable per tenant):
- `w_time = 30`, `w_detour = 20`, `w_capacity = 15`, `w_vehicle = 10`
- `maxDetourMiles = 8.0`
- `minTimeOverlapMinutes = 20`

**Time fit.** Overlap between order pickup window and itinerary departure
window ± travel time buffer. If overlap `< 20 min` → hard filter out.
Otherwise `timeFitScore = min(overlap / 60, 1.0)`.

**Detour.** Given the planned route polyline (approximated offline via great-
circle legs through origin → stops → destination), `detourMiles` is the extra
distance introduced by inserting pickup and dropoff at their optimal position.
If `detourMiles > 8.0` → hard filter out. Otherwise
`detourScore = 1 − (detourMiles / 8.0)`.

**Capacity.** Sum of already-accepted parcels plus candidate parcel vs
`vehicleCapacityVolumeL` and `vehicleCapacityWeightKg`. If exceeded → filter
out. Otherwise `capacityScore = 1 − utilization` with a `capacityRisk`
penalty when utilization > 0.8.

**Vehicle.** If `O.requiresVehicleType` is set and does not match
`I.vehicleType`, hard filter out; otherwise `vehicleScore = 1`.

**Conflict filter.** Orders already assigned to another courier, disputed,
or conflicting with existing accepted orders on the same itinerary (time /
capacity / vehicle) are removed before ranking.

### 5.3 Explanation strings

Each `MatchCandidate.explanationComponents` holds ordered
`{label, delta}` pairs used to render strings such as:

> `+30 time fit, +20 detour, −15 capacity risk`

The engine always emits the same factor order (time, detour, capacity,
vehicle, penalties) for stable UX. Deltas are the weighted contribution
(positive or negative) to the final score.

### 5.4 Recomputation

- On itinerary save / order change, the engine recomputes candidates for the
  affected itinerary + nearby orders (spatial+temporal window).
- A scheduled `BGAppRefreshTask` (identifier
  `com.eaglepoint.couriermatch.match.refresh`) recomputes stale candidates
  (`stale = YES` or older than 30 min) while respecting battery state — the
  engine yields when `ProcessInfo.processInfo.thermalState >= .serious` or
  `isLowPowerModeEnabled == YES`.

---

## 6. Notification Center (offline-safe)

### 6.1 Templates

Templated messages are rendered from `payloadJSON` using a deterministic
resolver. Template keys and required variables:

| Key | Variables | Example rendered |
|---|---|---|
| `assigned` | `orderRef`, `courierName` | `Order {orderRef} assigned to {courierName}.` |
| `picked_up` | `orderRef`, `pickupTime` | `Order {orderRef} picked up at {pickupTime}.` |
| `delivered` | `orderRef`, `deliveredTime` | `Order {orderRef} delivered at {deliveredTime}.` |
| `dispute_opened` | `orderRef`, `reason` | `Dispute opened on {orderRef}: {reason}.` |

Templates live in a bundled plist per locale and are admin-extensible per
tenant (config stored in `Tenant.configJSON`). Missing variables render as
`[n/a]` rather than crash.

### 6.2 Rate limiting

- Local rate limiter: no more than **5 announcements per minute** per
  `(tenantId, templateKey)` bucket.
- Enforced by `NotificationCenterService` using a `rateLimitBucket` derived
  from `floor(time/60)`; if the current minute already has 5 entries with
  the same key/tenant, the new item is **coalesced** (not dropped): a
  "digest" notification summarizes the excess and schedules it for the next
  minute boundary. Nothing is lost and no network is required.

### 6.3 Ack & read tracking

- Notifications render in a dedicated center with unread badge counts.
- Tapping marks `readAt`; explicit `Acknowledge` CTA marks `ackedAt` (used by
  dispatchers to evidence awareness of disputes).
- All transitions generate audit entries (`notification.read`, `notification.ack`).

### 6.4 Local system notifications

- Optional mirroring via `UNUserNotificationCenter` when app is in background
  (no remote push). All content is generated locally; delivery respects iOS
  authorization.

---

## 7. Data Quality, Normalization, and Concurrency

### 7.1 Normalization

- **Addresses.** `AddressNormalizer` trims whitespace, Title-cases city,
  maps state names → USPS two-letter abbreviation using an embedded table,
  validates ZIP to `^\d{5}(-\d{4})?$`. `normalizedKey` is
  `"{line1}|{city}|{stateAbbr}|{zip5}"` lower-cased, used for dedupe.
- **Dates.** All user-visible dates render `MM/dd/yyyy` and times `h:mm a`
  via `NSDateFormatter` locked to `en_US_POSIX` for the canonical form
  while honoring user locale for display labels. Internal storage uses
  `NSDate` (UTC).
- **Phone / IDs.** Stripped of non-digits where applicable; masking applied
  per §8.

### 7.2 Deduplication

- Orders: unique constraint `(tenantId, externalOrderRef)` enforced by Core
  Data merge policy `NSErrorMergePolicy` surfaces violations; UI prompts to
  merge / overwrite / keep existing.
- Addresses: soft dedupe via `normalizedKey` reuse.

### 7.3 Optimistic locking

- Every writable entity has `version` (int64). Writes use a
  `SaveWithVersionCheckPolicy`:
  1. Reader captured `version = V`.
  2. On save, fetch latest row with `refreshObject:mergeChanges:NO`.
  3. If current `version != V`, abort and raise conflict.
  4. Present **Keep Mine / Keep Theirs** sheet with a side-by-side diff of
     changed fields; chosen resolution is re-saved with `version = V+1`.
- All conflict resolutions generate audit entries including both snapshots.

---

## 8. Sensitive-data Masking

- `IDMasker` class: returns `"***-**-1234"` style masking for internal IDs,
  `"****@domain.com"` for emails, `"(***) ***-NN-NN"` style for phones.
- Screens default to **masked** view; explicit "Show" CTA requires
  re-authentication via biometrics (if enabled) or password prompt and logs
  a `sensitive.unmask_viewed` audit entry.
- Copying masked fields copies the masked string; copying unmasked fields
  is gated by the same re-auth gesture.

---

## 9. Delivery Quality Scoring

### 9.1 Rubric configuration

- `RubricTemplate` versions are immutable once applied to a scorecard — new
  versions become the default for subsequent deliveries.
- Admin UI allows adding `RubricItem`s with mode (automatic/manual), max
  points, and evaluator key (for automatic).

### 9.2 Automatic scorers

Built-in evaluators available in this build:

| `autoEvaluator` | Logic |
|---|---|
| `on_time_within_10min` | Actual delivery time within 10 minutes of `dropoffWindowEnd` → full points, else 0. |
| `photo_attached` | At least one Attachment of `image/*` type for the order → full points. |
| `signature_captured` | Signature attachment present (captured on-device via `PKCanvasView`-analog drawing view) → full points. |

Additional evaluators can be registered via `AutoScorerRegistry` without
code changes to the rubric engine.

### 9.3 Manual grading

- Reviewers grade subjective items (e.g., `packaging_condition`) via a
  slider/stepper bounded by `maxPoints`, with required notes when below
  `maxPoints / 2`.
- Each manual entry records grader user, timestamp, and notes.

### 9.4 Finalization

- `finalizeScorecard:` validates all items are filled, computes totals, and
  writes an `scorecard.finalize` audit entry with full before/after snapshots.
- Finalized scorecards are immutable; changes require an Appeal.

---

## 10. Disputes and Appeals

### 10.1 Intake

- Customer Service opens a `Dispute` referencing an `Order`, captures a
  reason (free text + reason category), attaches evidence.

### 10.2 Reviewer workflow

- A Reviewer is assigned (manual or round-robin per tenant config).
- The Reviewer opens an `Appeal` when a scorecard is being contested:
  - **Reason** (required)
  - **Reviewer** (auto-filled; reassignable by admin)
  - **Before-score snapshot** (locked JSON of the finalized scorecard)
  - **After-score snapshot** (reviewer's proposed scores; must respect rubric bounds)
  - **Decision**: uphold / adjust / reject, with notes.
- Finance reviews monetary-impact decisions before close (enforced via
  `appeal.close` requiring the Finance role when `impact.monetary = YES`).

### 10.3 Non-editable audit trail

- Every stage writes an `AuditEntry`. `appeal.decide` entries include the
  before/after scorecard snapshots, reviewer id, and decision notes.
- Audit entries are hash-chained: `entryHash = SHA256(prevHash ‖ canonical(entryFields))`,
  with the first entry anchored to a tenant-scoped HMAC seed held in the
  Keychain. Tampering produces a mismatched chain on audit verification, a
  scheduled background job performs periodic verification.

---

## 11. Attachments

### 11.1 Capture & permissions

- Camera access via `AVFoundation` gated by `NSCameraUsageDescription`; the
  app requests permission on first use and surfaces a non-blocking empty
  state if denied.
- Photo library access is optional (`NSPhotoLibraryUsageDescription`).

### 11.2 Validation

- Allowlist: `image/jpeg`, `image/png`, `application/pdf` only.
- Max size: 10 MB each (configurable downward per tenant).
- Validation is by magic-number sniff AND declared MIME; mismatches are
  rejected and logged as `attachment.reject`.

### 11.3 Storage & hashing

- Saved under app sandbox with `NSFileProtectionCompleteUnlessOpen`.
- `sha256Hex` computed at save and stored; re-validated on read (tamper
  detection). Mismatch raises `attachment.tamper_suspected` audit entry.
- Thumbnails generated off-main-thread and cached under
  `Caches/attachment-thumbs` (evicted on memory warning).

### 11.4 Cleanup

- A `BGProcessingTask` (identifier
  `com.eaglepoint.couriermatch.attachments.cleanup`) deletes attachments
  where `expiresAt < now` and removes orphaned thumbnails. Runs at most once
  per day and only when device is plugged in / not low-power.

---

## 12. Background Tasks

Registered at launch in `application:didFinishLaunchingWithOptions:`:

| Identifier | Type | Purpose |
|---|---|---|
| `com.eaglepoint.couriermatch.match.refresh` | `BGAppRefreshTask` | Recompute stale match candidates for active itineraries. |
| `com.eaglepoint.couriermatch.attachments.cleanup` | `BGProcessingTask` | Delete expired attachments; verify hashes. |
| `com.eaglepoint.couriermatch.notifications.purge` | `BGProcessingTask` | Purge expired / acked notifications older than retention window. |
| `com.eaglepoint.couriermatch.audit.verify` | `BGProcessingTask` | Verify audit hash chain integrity; raise in-app alert on break. |

Each task respects battery / thermal state and cooperatively yields to
`expirationHandler` by persisting partial progress and rescheduling.

---

## 13. Performance & Memory

### 13.1 Cold start target

Target: **< 1.5 s** on iPhone 11-class devices.

Strategy:
- Minimal work in `application:didFinishLaunchingWithOptions:`: Core Data
  stack initialization on a background queue, UI chrome assembly on main.
- First screen is a lightweight login / session-restore VC; heavy services
  (MatchEngine, AuditVerifier) are lazily instantiated on first use.
- No synchronous file I/O on main. No eager rubric or tenant scans.
- Launch screen is a pure storyboard (`LaunchScreen.storyboard`) with no
  code path, ensuring immediate paint.

### 13.2 Memory-warning handling

- `AppDelegate applicationDidReceiveMemoryWarning:` broadcasts
  `CMMemoryPressureNotification`.
- Handlers:
  - `ImageCacheService`: fully flush.
  - Active fetch requests with `fetchBatchSize > 50`: re-issued with smaller batch.
  - Off-screen view controllers with large table data sources: discard in-memory page caches and reload on demand.

### 13.3 Rendering & lists

- `UICollectionView` with diffable data sources and prefetching for match
  lists; reuse identifiers and `prepareForReuse` for cell image clears.
- Heavy formatting (date / address) memoized via `NSCache`.

---

## 14. UIKit, Accessibility, HIG Compliance

- All layout uses Auto Layout with `safeAreaLayoutGuide`. Constraints favor
  `readableContentGuide` for long-form text.
- `UITraitCollection`-driven appearance: Dark Mode via semantic colors
  (`UIColor labelColor`, `systemBackgroundColor`, etc.).
- **Dynamic Type**: all labels use preferred text styles with
  `adjustsFontForContentSizeCategory = YES`.
- **Split View** on iPad: `UISplitViewController` with three columns where
  available; collapses sensibly on compact size classes.
- **Landscape/portrait** adaptation via trait change hooks; scenes declare
  support for all interface orientations on iPad.
- **Haptics**: `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`
  fire for key actions (match accepted, appeal decided, permission denied).
- **Destructive actions** (account deletion): biometric re-auth required,
  confirmation sheet with explicit "This cannot be undone" copy.
- **Accessibility**: VoiceOver labels/hints on all interactive controls;
  large tap targets (44×44 pt minimum); color is never the sole carrier of
  state (paired with icon or text).

---

## 15. Security Hardening Summary

| Area | Control |
|---|---|
| Passwords | 12-char minimum, 1 digit + 1 symbol, pepper in Keychain, Argon2id/PBKDF2 hash |
| Lockout | 5 failures → 10-min lock |
| CAPTCHA | Required after 3 failures, local image CAPTCHA |
| Sessions | 15-min idle timeout, blur on background, Keychain-backed tokens |
| Forced logout | Admin-set sentinel invalidates sessions on next heartbeat |
| RBAC | `PermissionMatrix` plist; every controller action checks permission |
| Permission audit | Every role/permission change writes `permission.*` audit entry |
| Multi-tenant | `tenantId` on all records; query scoping enforced in repositories |
| Data at rest | Core Data with `NSFileProtectionComplete`; Keychain secrets; per-field AES-GCM for flagged columns |
| Attachments | MIME+magic allowlist, ≤ 10 MB, SHA-256 hashes, 30-day cleanup |
| Audit trail | Append-only, hash-chained, verified by background task |
| Sensitive masking | Default masked; unmask requires re-auth and audit entry |

---

## 16. Error Handling & Observability (local)

- Unified `CMError` domain with structured codes.
- A local, ring-buffered debug log (no PII) persisted under
  `Caches/debug-log` with `NSFileProtectionCompleteUnlessOpen`; accessible to
  admins via an in-app Diagnostics screen with share-sheet export (manual
  only). No automatic egress.
- All catchable exceptions funnel through a central reporter that shows an
  inline banner rather than crashing.

---

## 17. Testing Strategy

Unit tests (XCTest, Objective-C):
- Password policy, lockout, CAPTCHA gating.
- Address / date normalization.
- MatchEngine: boundary cases (detour at 7.99 / 8.00 / 8.01, overlap at
  19 / 20 / 21 min, vehicle mismatch).
- ScoringEngine: all automatic evaluators, manual bound enforcement.
- Notification rate limiter (5/min coalescing).
- Optimistic lock conflict resolution (Keep Mine / Keep Theirs).
- Audit hash chain: verify + intentional tamper detection.

Integration tests:
- End-to-end courier flow (create itinerary → get matches → accept → deliver → score).
- Dispute → Appeal → Finance close.
- Background task registration and expiration handling.

UI tests (XCUITest):
- VoiceOver traversal of login, match list, appeal form.
- Dynamic Type at largest accessibility size.
- Dark Mode visual regression on key screens.
- Split View on iPad across orientations.

Performance tests:
- Cold-start measurement with `XCTOSSignpostMetric`.
- Match recomputation throughput on 10k-order, 200-itinerary synthetic set.

---

## 18. Directory Layout (planned)

```
CourierMatch/
├── App/
│   ├── AppDelegate.{h,m}
│   └── SceneDelegate.{h,m}
├── Auth/
├── Itinerary/
├── Orders/
├── Match/
├── Notifications/
├── Scoring/
├── Appeals/
├── Audit/
├── Attachments/
├── Admin/
├── Common/
│   ├── Masking/
│   ├── Normalization/
│   ├── Theming/
│   ├── Accessibility/
│   └── Haptics/
├── Persistence/
│   ├── CoreData/
│   │   └── CourierMatch.xcdatamodeld
│   ├── Keychain/
│   └── Files/
├── Resources/
│   ├── LaunchScreen.storyboard
│   ├── Localizable.strings
│   └── Templates.plist
└── Tests/
    ├── Unit/
    ├── Integration/
    └── UI/
```

---

## 19. Open Design Decisions for Review

1. **Argon2id vs PBKDF2**: Argon2id is not in iOS CommonCrypto; pulling an
   Argon2 reference implementation adds a small C dependency. Fallback is
   PBKDF2-SHA256 with ≥ 310k iterations. Please confirm preference.
2. **Polyline routing offline**: pure great-circle legs underestimate real
   detour. Acceptable for this offline build, or should we ship a simple
   road-network approximation using a bundled grid heuristic?
3. **CAPTCHA style**: distorted text vs simple arithmetic. Distorted text is
   more adversarial-resistant; arithmetic is more accessible. Proposal:
   arithmetic by default with a "switch CAPTCHA" affordance.
4. **Per-field encryption surface**: confirm the field set flagged as
   "sensitive" — currently `sensitiveCustomerId` and flagged `customerNotes`.
5. **Audit retention**: audit entries are currently retained indefinitely.
   Confirm or set a tenant-configurable retention (with legal hold override).

---

*End of design document.*
