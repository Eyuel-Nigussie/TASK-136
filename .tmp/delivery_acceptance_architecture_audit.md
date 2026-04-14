# CourierMatch Delivery Acceptance & Architecture Audit (Static-Only)

## 1. Verdict
- Overall conclusion: **Partial Pass**

## 2. Scope and Static Verification Boundary
- Reviewed:
  - Documentation and project config (`repo/README.md`, `repo/project.yml`, `repo/Makefile`, `docs/design.md`, `docs/questions.md`).
  - App entry/navigation/auth/session/security/core business modules/persistence/audit/logging/tests.
  - Core files across `App/`, `Auth/`, `Orders/`, `Match/`, `Notifications/`, `Scoring/`, `Appeals/`, `Attachments/`, `Admin/`, `Persistence/`, `Tests/`.
- Not reviewed exhaustively:
  - Every UI screen pixel/layout detail and every file in all modules line-by-line.
- Intentionally not executed:
  - App launch/run, tests, Docker, network/external services (per static-only rules).
- Claims requiring manual verification:
  - Cold start `<1.5s`, memory-warning behavior under real pressure, BG task execution timing under iOS scheduler/battery conditions, real camera/photo permission behavior, biometric device behavior, runtime split-view ergonomics.

## 3. Repository / Requirement Mapping Summary
- Prompt core goal mapped: offline native iOS Objective-C UIKit app for dispatch/matching/notifications/scoring/disputes/appeals/audit/security with multi-tenant Core Data.
- Main implementation areas mapped:
  - Auth/session hardening (`repo/Auth/*`, `repo/Persistence/Keychain/*`).
  - Matching/scoring/appeals (`repo/Match/*`, `repo/Scoring/*`, `repo/Appeals/*`).
  - Notification center and rate limiting (`repo/Notifications/*`).
  - Multi-tenant persistence + encryption + audit chain (`repo/Persistence/*`, `repo/Audit/*`, data model).
  - Admin and RBAC surfaces (`repo/Admin/*`, `repo/Resources/PermissionMatrix.plist`).
  - Unit/integration/UI tests (`repo/Tests/*`).

## 4. Section-by-section Review

### 1. Hard Gates
#### 1.1 Documentation and static verifiability
- Conclusion: **Pass**
- Rationale: Build/test/config instructions and project structure are present and statically coherent for an iOS/XcodeGen repo.
- Evidence: `repo/README.md:10`, `repo/README.md:94`, `repo/README.md:112`, `repo/project.yml:1`, `repo/project.yml:25`
- Manual verification note: Real command success cannot be confirmed statically.

#### 1.2 Material deviation from Prompt
- Conclusion: **Partial Pass**
- Rationale: Core domain is implemented, but there are material deviations in authorization depth and notification-rate semantics versus prompt constraints.
- Evidence: `repo/Orders/CMOrderDetailViewController.m:118`, `repo/Admin/CMAdminDashboardViewController.m:211`, `repo/Notifications/CMNotificationRateLimiter.m:36`, `repo/Notifications/CMNotificationRateLimiter.m:62`

### 2. Delivery Completeness
#### 2.1 Core requirements coverage
- Conclusion: **Partial Pass**
- Rationale:
  - Implemented: matching filters/scoring/explanations, in-app notification center, scoring+appeal flow, lockout/CAPTCHA/session timeout, Core Data tenant model, attachment allowlist/hash/cleanup, iPhone+iPad navigation scaffolding.
  - Gaps/defects: global 5/min announcement cap is not global; function-level authorization is inconsistent for sensitive mutations.
- Evidence: `repo/Match/CMMatchEngine.m:130`, `repo/Notifications/CMNotificationCenterService.m:84`, `repo/Auth/CMLockoutPolicy.m:11`, `repo/Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents:72`, `repo/Notifications/CMNotificationRateLimiter.m:36`, `repo/Orders/CMOrderDetailViewController.m:118`

#### 2.2 End-to-end deliverable (0→1) vs partial demo
- Conclusion: **Pass**
- Rationale: Repository is product-structured multi-module iOS app with targets and substantial tests; not a single-file demo.
- Evidence: `repo/project.yml:25`, `repo/project.yml:124`, `repo/project.yml:173`, `repo/README.md:112`

### 3. Engineering and Architecture Quality
#### 3.1 Structure and decomposition quality
- Conclusion: **Pass**
- Rationale: Modules are separated by domain and infrastructure; persistence repositories and services are split logically.
- Evidence: `repo/README.md:129`, `repo/Persistence/Repositories/CMRepository.m:27`, `repo/Scoring/CMScoringEngine.m:1`, `repo/Notifications/CMNotificationCenterService.m:1`

#### 3.2 Maintainability/extensibility
- Conclusion: **Partial Pass**
- Rationale: Extensible decomposition exists, but security-critical authorization is too UI-coupled in places, reducing long-term safety.
- Evidence: `repo/Orders/CMOrderDetailViewController.m:507`, `repo/Orders/CMOrderDetailViewController.m:118`, `repo/Admin/CMAdminDashboardViewController.m:105`, `repo/Admin/CMAdminDashboardViewController.m:211`

### 4. Engineering Details and Professionalism
#### 4.1 Error handling/logging/validation/API shape
- Conclusion: **Partial Pass**
- Rationale: Strong validation and error patterns exist broadly, but security enforcement depth is inconsistent in mutation paths.
- Evidence: `repo/Auth/CMAuthService.m:81`, `repo/Auth/CMAuthService.m:201`, `repo/Common/Errors/CMDebugLogger.h:24`, `repo/Orders/CMOrderDetailViewController.m:239`

#### 4.2 Product-level quality vs demo
- Conclusion: **Pass**
- Rationale: Delivers app-scale codebase with multiple user-role workflows, persistence, auditing, and tests.
- Evidence: `repo/README.md:6`, `repo/README.md:129`, `repo/Tests/Unit/MODULE.md:1`, `repo/Tests/Integration/MODULE.md:1`

### 5. Prompt Understanding and Requirement Fit
#### 5.1 Business understanding and constraint fit
- Conclusion: **Partial Pass**
- Rationale: Business scenario is largely reflected, but key semantics are violated by (a) non-global announcement throttling and (b) authz enforcement gaps on sensitive actions.
- Evidence: `repo/Notifications/CMNotificationRateLimiter.m:36`, `repo/Notifications/CMNotificationRateLimiter.m:62`, `repo/Orders/CMOrderDetailViewController.m:118`, `repo/Admin/CMAdminDashboardViewController.m:250`

### 6. Aesthetics (frontend-only/full-stack)
#### 6.1 Visual/interaction quality fit
- Conclusion: **Cannot Confirm Statistically**
- Rationale: UIKit/Dynamic Type/Dark Mode and split-view code plus UI tests exist, but visual fidelity and interaction quality require runtime/manual UX review.
- Evidence: `repo/App/SceneDelegate.m:253`, `repo/Tests/UI/CMDarkModeUITests.m:1`, `repo/Tests/UI/CMDynamicTypeUITests.m:1`, `repo/Tests/UI/CMiPadSplitViewUITests.m:1`
- Manual verification note: manual UI/UX walkthrough on iPhone+iPad in portrait/landscape is required.

## 5. Issues / Suggestions (Severity-Rated)

### Blocker
1. Severity: **Blocker**
- Title: Sensitive mutations rely on UI gating; missing function-level authorization enforcement
- Conclusion: **Fail**
- Evidence:
  - Order mutations execute without permission checks in the mutation methods: `repo/Orders/CMOrderDetailViewController.m:118`, `repo/Orders/CMOrderDetailViewController.m:163`, `repo/Orders/CMOrderDetailViewController.m:239`
  - Permissions are only used to decide which buttons are shown: `repo/Orders/CMOrderDetailViewController.m:507`
  - Admin role gate occurs at screen load, but mutation handlers do not re-check role/permission: `repo/Admin/CMAdminDashboardViewController.m:105`, `repo/Admin/CMAdminDashboardViewController.m:211`, `repo/Admin/CMAdminDashboardViewController.m:250`
- Impact: If UI/state/navigation is bypassed or regresses, unauthorized users may perform assignment/note edits/role changes/forced logout.
- Minimum actionable fix: Move sensitive mutations into service/repository methods that enforce permission and role checks server-style (in-process), and make controllers call those APIs only.

### High
2. Severity: **High**
- Title: Notification rate limit is per-template, not global 5 announcements/minute
- Conclusion: **Fail**
- Evidence:
  - Bucket key includes `templateKey`: `repo/Notifications/CMNotificationRateLimiter.m:36`, `repo/Notifications/CMNotificationRateLimiter.m:40`
  - Coalescing threshold check applies per bucket: `repo/Notifications/CMNotificationRateLimiter.m:62`
  - Caller passes per-event template key: `repo/Notifications/CMNotificationCenterService.m:88`, `repo/Notifications/CMNotificationCenterService.m:99`
- Impact: App can emit >5 announcements/min by spreading events across template keys, violating prompt throttling semantics.
- Minimum actionable fix: Rate-limit by tenant(+recipient) minute bucket globally, not per template; keep template-level logic only for digest grouping if needed.

3. Severity: **High**
- Title: On-time scorer uses mutable `updatedAt` as delivery timestamp
- Conclusion: **Fail**
- Evidence:
  - Scorer reads `order.updatedAt` as actual delivery time: `repo/Scoring/CMAutoScorer_OnTime.m:38`
  - `Order` model has no dedicated immutable `deliveredAt`: `repo/Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents:72`
  - Unrelated edits update `updatedAt` (e.g., notes edit): `repo/Orders/CMOrderDetailViewController.m:262`
- Impact: Objective scoring can drift after post-delivery edits, undermining compliance/audit reliability.
- Minimum actionable fix: Add immutable `deliveredAt`, set only on transition to Delivered, and base on-time scoring exclusively on `deliveredAt`.

4. Severity: **High**
- Title: Finance role access to adjustment workflow is inconsistent across device form factors
- Conclusion: **Partial Fail**
- Evidence:
  - iPhone tab condition excludes finance from Scoring tab: `repo/App/SceneDelegate.m:347`
  - Monetary-impact decisions require finance role: `repo/Appeals/CMAppealService.m:196`
- Impact: Finance-adjustment workflow availability depends on device/nav path, conflicting with predictable role-based operations.
- Minimum actionable fix: Provide explicit finance-accessible entrypoint for appeals/adjustments on all supported form factors.

### Medium
5. Severity: **Medium**
- Title: Biometric login path checks token existence but does not verify user biometric enrollment flags
- Conclusion: **Partial Fail**
- Evidence:
  - Biometric login succeeds if keychain token exists for `userId`: `repo/Auth/CMAuthService.m:324`, `repo/Auth/CMAuthService.m:326`
  - User fetch then checks only active status, not `biometricEnabled`/`biometricRefId`: `repo/Auth/CMAuthService.m:347`
- Impact: Stale or orphaned keychain token conditions are not explicitly constrained by enrollment flags.
- Minimum actionable fix: Require `biometricEnabled == YES` and `biometricRefId` match before allowing biometric sign-in; add disable/revoke flow.

6. Severity: **Medium**
- Title: Security-critical authorization gaps are not directly covered by tests
- Conclusion: **Fail (coverage dimension)**
- Evidence:
  - Strong auth/lockout tests exist: `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:150`, `repo/Tests/Unit/CMLockoutPolicyTests.m:189`
  - No direct tests for unauthorized invocation of order/admin mutation handlers (static search scope and available suites show no coverage for those controller actions).
- Impact: Severe permission regressions can pass CI undetected.
- Minimum actionable fix: Add tests asserting denied mutations for unauthorized roles at service/API boundary; avoid relying on UI visibility tests.

## 6. Security Review Summary

- Authentication entry points: **Pass**
  - Evidence: Password login with policy/lockout/CAPTCHA/session binding exists (`repo/Auth/CMAuthService.m:153`, `repo/Auth/CMAuthService.m:201`, `repo/Auth/CMLockoutPolicy.m:11`).

- Route-level authorization: **Not Applicable**
  - Rationale: Native iOS app with no HTTP routes in scope.

- Object-level authorization: **Partial Pass**
  - Evidence: Courier own-order status check exists (`repo/Orders/CMOrderDetailViewController.m:525`), tenant-scoped repository predicates exist (`repo/Persistence/Repositories/CMRepository.m:33`).
  - Gap: Multiple mutations still rely on UI gating and lack independent enforcement.

- Function-level authorization: **Fail**
  - Evidence: Sensitive mutation handlers lack internal permission checks (`repo/Orders/CMOrderDetailViewController.m:118`, `repo/Admin/CMAdminDashboardViewController.m:211`).

- Tenant / user data isolation: **Pass**
  - Evidence: tenant-scoping predicate with `deletedAt == nil` (`repo/Persistence/Repositories/CMTenantContext.m:48`), tenantId present across entities (`repo/Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents:22`, `repo/Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents:72`, `repo/Persistence/CoreData/CourierMatch.xcdatamodeld/CourierMatch.xcdatamodel/contents:287`).

- Admin / internal / debug protection: **Partial Pass**
  - Evidence: Admin screen role gate in `viewDidLoad` (`repo/Admin/CMAdminDashboardViewController.m:105`).
  - Gap: critical admin actions do not re-assert authorization at action layer (`repo/Admin/CMAdminDashboardViewController.m:211`, `repo/Admin/CMAdminDashboardViewController.m:250`).

## 7. Tests and Logging Review
- Unit tests: **Pass (existence/scope), Partial Pass (risk depth)**
  - Evidence: substantial unit suite for lockout, match, normalization, scoring, rate limiting (`repo/Tests/Unit/MODULE.md:5`, `repo/Tests/Unit/CMLockoutPolicyTests.m:147`, `repo/Tests/Unit/CMMatchEngineTests.m:161`, `repo/Tests/Unit/CMNotificationRateLimiterTests.m:76`).

- API / integration tests: **Pass (existence), Partial Pass (authorization depth)**
  - Evidence: auth, courier flow, notification coalescing, dispute/appeal integration (`repo/Tests/Integration/MODULE.md:5`, `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:150`, `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:79`).

- Logging categories / observability: **Pass**
  - Evidence: tagged leveled logger macros and module tags (`repo/Common/Errors/CMDebugLogger.h:39`, `repo/Notifications/CMNotificationCenterService.m:124`, `repo/Auth/CMSessionManager.m:63`).

- Sensitive-data leakage risk in logs/responses: **Partial Pass**
  - Evidence: redaction utility used in many sensitive IDs (`repo/Common/Errors/CMDebugLogger.m:66`, `repo/Auth/CMSessionManager.m:63`, `repo/Notifications/CMNotificationCenterService.m:346`).
  - Residual risk: logger contract is caller-enforced (`repo/Common/Errors/CMDebugLogger.h:24`), so misuse remains possible.

## 8. Test Coverage Assessment (Static Audit)

### 8.1 Test Overview
- Unit + integration + UI tests exist.
- Framework: XCTest (unit/integration/UI).
- Test targets/entry points defined in XcodeGen scheme.
- Documentation includes test commands.
- Evidence: `repo/project.yml:124`, `repo/project.yml:173`, `repo/project.yml:201`, `repo/README.md:38`, `repo/README.md:94`

### 8.2 Coverage Mapping Table
| Requirement / Risk Point | Mapped Test Case(s) | Key Assertion / Fixture / Mock | Coverage Assessment | Gap | Minimum Test Addition |
|---|---|---|---|---|---|
| Password policy + failed attempts + lockout + CAPTCHA | `repo/Tests/Unit/CMLockoutPolicyTests.m:147`; `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:150` | 3-failure CAPTCHA trigger and 5-failure 10-min lock asserted (`repo/Tests/Unit/CMLockoutPolicyTests.m:189`, `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:189`) | sufficient | None major | Add negative tests for unknown-user brute-force behavior if required by policy |
| Tenant scoping / isolation predicate | `repo/Tests/Unit/CMTenantContextTests.m:79` | Predicate includes tenant + `deletedAt nil` (`repo/Tests/Unit/CMTenantContextTests.m:89`, `repo/Tests/Unit/CMTenantContextTests.m:97`) | basically covered | No direct cross-tenant mutation abuse tests | Add integration tests for cross-tenant fetch/mutate denial on core repositories |
| Match scoring constraints (detour/time/capacity) | `repo/Tests/Unit/CMMatchEngineTests.m:161` | Deterministic scoring harness with filter behavior in test engine (`repo/Tests/Unit/CMMatchEngineTests.m:110`) | basically covered | End-to-end UI flow not covered | Add integration test from itinerary creation -> ranked candidate persistence |
| Notification rate limiting | `repo/Tests/Unit/CMNotificationRateLimiterTests.m:76`; `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:95` | Explicitly validates per-template independence (`repo/Tests/Unit/CMNotificationRateLimiterTests.m:155`) | insufficient vs prompt | Tests enforce wrong semantics (per-template, not global 5/min) | Add tests that cap total announcements per minute across mixed template keys |
| Dispute/appeal lifecycle + finance constraints | `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:79` | Finance role close flow asserted (`repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:188`, `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:194`) | basically covered | Device-form-factor access path not tested | Add UI/integration tests ensuring finance can reach required flows on iPhone+iPad |
| On-time objective scoring correctness | `repo/Tests/Unit/CMScoringEngineTests.m:129` | Uses helper delivered offset assumptions (`repo/Tests/Unit/CMScoringEngineTests.m:131`) | insufficient | Does not guard against `updatedAt` mutation after delivery | Add regression test: edit notes after delivery must not alter on-time score |
| Function-level authorization for sensitive order/admin mutations | No direct tests found in suites | Existing tests focus on auth/login and service flows | missing | Privilege escalation risks can pass tests | Add role-denial tests on mutation service methods for assign/edit notes/role change/force logout |
| UI adaptability (iPad split / rotation) | `repo/Tests/UI/CMiPadSplitViewUITests.m:39` | Orientation and split-view presence checks (`repo/Tests/UI/CMiPadSplitViewUITests.m:76`) | basically covered | Mostly smoke-level UI assertions | Add role-based navigation availability assertions per form factor |

### 8.3 Security Coverage Audit
- Authentication: **Covered well** (lockout/CAPTCHA/session tests exist).
- Route authorization: **Not Applicable** (no HTTP API routes).
- Function/role authorization: **Insufficient** (no direct negative tests for unauthorized mutation handlers).
- Tenant/data isolation: **Partially covered** (predicate tests exist; aggressive abuse-path tests limited).
- Admin/internal protection: **Insufficient** (no direct tests for non-admin invocation of admin mutation methods).

### 8.4 Final Coverage Judgment
- **Partial Pass**
- Covered: auth hardening, key business flows (matching/scoring/appeals), core UI smoke.
- Uncovered critical risks: function-level authorization bypass and incorrect notification throttling semantics; severe defects could still pass existing tests.

## 9. Final Notes
- Findings above are static-evidence based and line-traceable.
- Runtime/performance/device-behavior conclusions are intentionally not overstated.
- Highest-priority remediation should target authorization hardening and global notification throttling correctness before acceptance.
