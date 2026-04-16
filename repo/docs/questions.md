# CourierMatch — Open Questions and Solutions

---

## Q1. Argon2id availability without third-party dependencies

**Question:** Apple's CommonCrypto does not ship Argon2id. Shipping an Objective-C/C Argon2 reference implementation means adding ~1.5 KLOC of vendored C code and taking on its license and audit burden. Is adding this dependency acceptable, or must we stay strictly within Apple frameworks?

**My understanding and solution:** The project wants zero third-party code and no vendored C. I implement password hashing with **PBKDF2-SHA512** via `CCKeyDerivationPBKDF`, fixed at **600,000 iterations**, 32-byte salt (per user), and a 32-byte pepper pulled from the Keychain item `cm.auth.pepper` (generated once at first launch with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). Iteration count is stored alongside the hash so we can migrate upward without breaking existing accounts. A feature flag `kCMAuthKDF` remains reserved for a future Argon2id swap.

---

## Q2. Offline detour distance is not actual road distance

**Question:** "Detour miles" is central to the 8-mile filter and scoring, but without a routing server or bundled road network, a great-circle computation can understate real road detour by 30%+ on urban grids and overstate on highways. Are we comfortable with great-circle, or do we need a better offline approximation?

**My understanding and solution:** Accepting great-circle inaccuracy is not acceptable for a product that makes assignment decisions on it. I compute detour as `greatCircle(origin → pickup → dropoff → destination) − greatCircle(origin → destination)` and then apply a **piecewise urban-adjustment multiplier** of `1.35` when both endpoints fall within a bundled list of "dense metro" ZIP prefixes (shipped as a small plist), and `1.15` otherwise. Detour miles displayed in the UI are always the adjusted value. The multiplier is exposed in `Tenant.configJSON` so admins can recalibrate. A disclaimer string ("estimated — offline routing") is rendered next to the detour value.

---

## Q3. Time-fit "overlap" semantics when windows are not colinear

**Question:** The design says `overlap = min(orderPickup.end, itinerary.departureEnd) − max(orderPickup.start, itinerary.departureStart)`, but does not address **travel time from the itinerary origin to the pickup**. A courier whose departure starts at 9:00 may not reach the pickup until 9:40; the raw overlap is then misleading.

**My understanding and solution:** Overlap must be computed against the estimated pickup arrival time, not the raw departure window. I use `etaAtPickup = itinerary.departureStart + travelMinutes(origin → pickup)` where `travelMinutes` is computed from `adjustedDetourMiles` and a vehicle-type average speed (bike 10 mph, car/van 25 mph urban / 45 mph rural, truck 22 / 40 mph). Overlap is then `min(orderPickup.end, etaAtPickup + maxWait) − max(orderPickup.start, etaAtPickup)` with `maxWait` = 60 minutes. If overlap < 20 min → hard filter. The explanation string exposes the ETA ("arrives ~9:42, window 9:30–10:30").

---

## Q4. Tie-breaking in match rankings

**Question:** When two candidates produce identical composite scores, the design does not specify order. Non-deterministic ordering undermines the audit trail ("which ranking did the courier actually see?").

**My understanding and solution:** Ordering should be deterministic and auditable. I sort by `(score DESC, detourMiles ASC, orderPickupWindowStart ASC, orderId ASC)`. The last component guarantees stability across runs. `MatchCandidate.rankPosition` is persisted so the courier-observed ranking can be reproduced for audits even after the underlying scores have been recomputed.

---

## Q5. BGAppRefreshTask is not guaranteed to run

**Question:** iOS grants `BGAppRefreshTask` opportunistically — it may not fire for days if the user rarely opens the app. The design depends on it to keep `MatchCandidate` fresh and to verify audit chains. What is the staleness budget, and what is the fallback?

**My understanding and solution:** We cannot rely on iOS scheduling for freshness guarantees. I treat all background tasks as best-effort. Each relevant read path does a lazy freshness check: when a courier opens the itinerary list, the view model asks `MatchEngine isCandidateStale:` for the itinerary; if true, the engine recomputes synchronously on a background queue with a non-blocking UI (skeleton cells). The same pattern applies to audit verification — on the Admin Diagnostics screen and at first successful admin login after 24 h of no verification. A visible "Last refreshed at …" timestamp is shown so operators can see when data was last recomputed.

---

## Q6. Notification rate-limit coalescing — ordering and retention

**Question:** Section 6.2 says "excess notifications coalesce into a digest," but does not specify: (a) whether coalesced items are still individually audited, (b) whether `readAt`/`ackedAt` apply to the digest or the underlying items, (c) what happens if the next minute is also saturated (cascade).

**My understanding and solution:** Each original notification is a first-class audit event; the digest is a UI affordance, not a replacement. I persist every individual `NotificationItem` with `status = coalesced` when it exceeds the 5/min bucket; generate an additional `NotificationItem` with `templateKey = digest` that holds an array of `childIds`. Read/ack on the digest cascades to children. Cascades across minutes are handled by re-evaluating the digest at each minute boundary: if the next minute still saturates, the digest rolls forward (single digest covers multiple minutes), up to a max of 15 minutes after which a new digest is created. Audit entries are always written per-original.

---

## Q7. Core Data `NSFileProtectionComplete` vs background execution

**Question:** `NSFileProtectionComplete` makes the SQLite store unreadable while the device is locked. Background tasks scheduled for attachment cleanup, audit verification, and notification purge will fail immediately if the device is locked (common overnight). Do we accept this, or relax protection?

**My understanding and solution:** The security requirement cannot be relaxed globally. I use a **split protection strategy**: Core Data SQLite main file uses `NSFileProtectionComplete` (sensitive reads). A small **work-queue sidecar store** (`work.sqlite`) for cleanup-only metadata (attachment paths + expiry, notification IDs + expiry, audit verification cursor) uses `NSFileProtectionCompleteUntilFirstUserAuthentication`. Background tasks only touch the sidecar + files with `NSFileProtectionCompleteUnlessOpen`. Main Core Data is only opened from background when the device is unlocked (detected via `UIApplication.isProtectedDataAvailable`). If unavailable, the task reschedules and exits gracefully.

---

## Q8. Audit hash chain across multiple tenants on one device

**Question:** Section 10.3 says audit entries are hash-chained "anchored to a tenant-scoped HMAC seed." Does this mean one chain per tenant, or one chain across all tenants? A single chain leaks cross-tenant ordering; per-tenant chains allow tenant-level export/verification but permit an insider admin to delete a tenant's chain entirely.

**My understanding and solution:** Per-tenant chains are required for the multi-tenant boundary. I maintain **one chain per tenant**. Seed is stored in Keychain as `cm.audit.seed.<tenantId>` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Additionally, every chain head is mirrored into a **device-wide meta-chain** (`cm.audit.meta`) that records `(tenantId, newHead, actorUserId, ts)` entries. Deleting a tenant's chain becomes detectable because the meta-chain still references the last known head. The meta-chain seed is not deletable through any in-app flow (not even by admins).

---

## Q9. Optimistic locking conflict granularity

**Question:** The "Keep Mine / Keep Theirs" design operates at row level. What happens when two users edit **different** fields of the same order (e.g., one edits `customerNotes`, the other edits `pickupWindowEnd`)? Row-level last-writer-wins loses real user work and will feel broken.

**My understanding and solution:** Field-level merging is required for edits that affect disjoint fields; row-level conflict only applies when they overlap. During save, I compute the set of fields changed since the base version and diff them against the set of fields changed by the competing commit. If the sets are disjoint, **auto-merge** silently and bump `version` twice (with both changes represented in the audit entry). If they overlap, present the Keep Mine / Keep Theirs sheet, but scoped to **only the overlapping fields** (non-overlapping fields auto-merge regardless of choice). The audit entry records which fields merged and which were chosen.

---

## Q10. "Local CAPTCHA" threat model

**Question:** A CAPTCHA rendered locally, validated locally, with its answer hash stored locally, can be bypassed by any attacker with debug access to the app's memory or database. Is the goal (a) blocking human-paced brute force on a stolen/unlocked device, or (b) actual adversarial robustness?

**My understanding and solution:** The goal is (a): slow a human tapping the login UI on an unlocked device, not defeat a rooted attacker. I implement a simple arithmetic CAPTCHA rendered with Core Graphics; validate via constant-time comparison against a HMAC-SHA256 of the answer keyed with a per-challenge nonce held only in memory (never persisted). The threat model is documented explicitly in the design so future reviewers don't assume more. I do not claim adversarial robustness — the CAPTCHA exists to rate-limit human interaction, not to defeat a rooted attacker.

---

## Q11. Forced-logout heartbeat cost and latency

**Question:** Section 4.1 compares `UserAccount.forceLogoutAt` to `Session.issuedAt` "on each heartbeat." What frequency? A 1-second heartbeat wastes battery; a 5-minute one means an admin force-logout can take up to 5 minutes to actually kick a user out.

**My understanding and solution:** The security team expects forced logout to take effect within 60 seconds. I set the heartbeat to every **30 seconds** while foregrounded and on every app resume from background. Additionally I check `forceLogoutAt` synchronously before every **sensitive action** (score finalization, appeal decision, permission change, data export, attachment upload). Non-sensitive reads are not heartbeat-gated. This bounds worst-case logout latency at 30 s for foregrounded idle users and 0 s for anyone about to take a sensitive action.

---

## Q12. CSV/JSON itinerary import: untrusted file handling

**Question:** Itinerary import via `UIDocumentPickerViewController` accepts arbitrary files. Risks include: extremely large files, malformed encodings, CSV formula injection (`=cmd|...`), oversize fields that bloat Core Data, and UTF-8 BOM/CR-LF inconsistencies.

**My understanding and solution:** Hardened import is required; silent acceptance is not. My import pipeline: (1) Hard size limit: **2 MB** per file; reject larger with a clear error. (2) Stream-parse line by line; cap **10,000 rows** per import. (3) Per-field length cap (512 chars for text, 2 KB total row) with truncation + warning, not rejection. (4) Normalize line endings and strip BOM. (5) Neutralize leading `=`, `+`, `-`, `@` by prefixing a single quote during storage (defuses formula-injection propagation to any future export). (6) Schema-validate columns; unknown columns ignored with a warning. (7) All rejected rows surface in a per-import summary screen with a per-row reason, persisted for 30 days alongside the imported batch.

---

## Q13. Attachment hashing on a user-facing thread

**Question:** Computing SHA-256 over a 10 MB PDF on-device can take ~100–300 ms on an iPhone 11. If done on the main thread during capture, it will cause UI hitches and undermine the < 1.5 s cold-start feel during normal capture flows.

**My understanding and solution:** All hashing must be off-main. I route every hash computation through `AttachmentHashingService` backed by a dedicated `NSOperationQueue` (`qualityOfService = .userInitiated`, `maxConcurrentOperationCount = 2`). The UI shows a non-blocking "Verifying…" badge on the attachment row; the attachment is saved optimistically and only transitions to `ready` after hash completes. Re-validation on read follows the same pattern; mismatch raises a modal + audit entry.

---

## Q14. Core Location reduced accuracy semantics

**Question:** `kCLLocationAccuracyReduced` yields fuzzed locations (often ~5 km resolution). That is often too coarse to pre-fill a real street-level origin address. Is the point to pre-fill an *address* or just a *region*?

**My understanding and solution:** Region-level prefill is the intended UX; street-level accuracy would require full-accuracy authorization I do not want. I prefill only at the **city + state + ZIP** level, leaving `line1` blank for the user to complete manually. The prefill is clearly labeled as "approximate location." I offer an opt-in "Use precise location for this itinerary" button that requests `requestTemporaryFullAccuracyAuthorization` with purpose key `ItineraryOrigin`; precise location is **never cached** beyond the current itinerary draft and is discarded on save.

---

## Q15. Time-zone and DST correctness for windows and on-time scoring

**Question:** Windows are stored as `NSDate` (UTC). On-time within 10 minutes, MM/dd/yyyy display, and audit timestamps all cross time-zone boundaries when a courier travels or when DST changes. Whose time zone defines "on time"?

**My understanding and solution:** On-time is defined by the **order's local time zone**, not the device's current zone. Every `Order` stores an explicit `pickupTimeZoneIdentifier` and `dropoffTimeZoneIdentifier` (IANA string, derived from the dropoff ZIP via a bundled ZIP→tz table). All window arithmetic uses the stored zone. All user-facing times render in the window's zone by default with a "(device time: …)" subtitle when different. Audit timestamps are stored UTC but always rendered with the viewer's zone and the UTC offset annotated.

---

## Q16. Export and data egress control

**Question:** The app is offline, but iOS affords sharing via `UIActivityViewController`, AirDrop, drag-and-drop, and screenshots. Audit evidence, diagnostics export, and attachment preview can all exfiltrate sensitive data. What is the egress policy?

**My understanding and solution:** Egress must be controlled and audited where technically possible. Sensitive VCs suppress screen recording by overlaying a `UITextField`-backed secure-entry snapshot barrier on the most sensitive views (audit log, appeal decision screen, permission change screen). All share-sheet invocations go through `CMExportService` which: checks role permission for the data kind, writes an `export.initiated` audit entry with actor/kind/record count, strips the sensitive-field encryption before sharing (plaintext export) only for admin/finance roles, and applies per-tenant watermarks on PDF exports. Screenshots cannot be blocked by iOS; I surface a warning banner on sensitive screens and write an `screen.maybe_captured` audit entry (best-effort detection via `UIScreen.capturedDidChangeNotification`).

---

## Q17. Maximum dataset sizes and Core Data performance cliffs

**Question:** The design does not state expected volumes. Core Data with SQLite handles millions of rows, but `MatchCandidate` recomputation fetches can balloon: 500 itineraries × 10k orders = 5M candidate evaluations per pass.

**My understanding and solution:** Single-device steady state is ≤ 50k active orders and ≤ 1k active itineraries per tenant, with ≤ 5 tenants per device. I enforce a **spatio-temporal pre-filter** before scoring: only evaluate orders whose pickup window is within ±24h of the itinerary's departure window, and only evaluate orders whose pickup ZIP centroid is within a bounding box of `2 × maxDetourMiles × urbanMultiplier` around the itinerary polyline. This is an indexed SQL query, not an in-memory scan. Worst-case candidate count per itinerary is bounded at **500**; above that, the engine emits a `match.truncated` audit entry and shows a "refine itinerary" hint.

---

## Q18. Handling rubric version changes during open scorecards

**Question:** An admin publishes a new `RubricTemplate` version while a scorecard is open but not finalized. The design says rubrics are immutable once applied, but when exactly is a rubric "applied" — at scorecard creation or at finalization?

**My understanding and solution:** The rubric is applied at scorecard creation, but reviewers must be able to see that a newer version exists. `DeliveryScorecard` captures `rubricId` + `rubricVersion` at creation and uses that version for all scoring. If a newer version exists at the time the reviewer opens the scorecard, I show a banner: "A newer rubric is available. Continue on v{n} or restart on v{n+1}?" Restart creates a new scorecard linked to the prior via `supersedesScorecardId` and writes a `scorecard.rubric_upgraded` audit entry.

---

## Q19. Deleting an account and legal hold

**Question:** "Account deletion" is described as destructive and biometric-gated. Does deletion wipe the audit trail and appeal history for that user? That conflicts with the non-editable audit requirement.

**My understanding and solution:** Audit and appeal history must be preserved even after user deletion — the user entity is tombstoned, not removed. "Delete account" sets `UserAccount.status = deleted` and clears `passwordHash`, `biometricRefId`, session state, and personal display metadata (display name replaced with "Deleted user (#{shortHash})"). `userId` remains intact so all audit, login history, appeal decisions, and scorecard grader references continue to resolve. Physical removal is a separate admin-only operation behind a "Legal purge" confirmation that requires typing the tenant name and produces a `user.physical_purge` audit entry (the physical purge itself is preserved in that entry plus the meta-chain).

---

## Q20. iPad multitasking and session timeout interactions

**Question:** With `UISplitViewController` on iPad, a user can be actively reading in the secondary column while the primary is unchanged. If our activity detector only listens to gestures on the primary, the 15-minute timeout could fire while the user is actively scrolling. Conversely, background Slide Over makes the app "active but not focused."

**My understanding and solution:** Activity must be detected across all scene windows, and backgrounded-but-visible states are treated as inactive for timeout purposes. I install a root `UIWindow` gesture recognizer (with `UIGestureRecognizerDelegate` returning pass-through so the UI is unaffected) on every window in every connected scene, feeding a single `SessionManager recordActivity` call. Scene lifecycle hooks (`sceneDidEnterBackground:`, `sceneWillResignActive:`) do **not** extend activity; they pause the timer only when the scene is actually hidden (foreground Slide Over where our scene is unfocused counts as inactive per security intent). A 30-second post-background grace period exists per §4.3 so quick task-switches don't force full re-auth.
