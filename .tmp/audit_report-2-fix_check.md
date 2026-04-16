# Audit Report 2 - Fix Check (Item-by-Item)

## Scope Checked
Compared every original remark in `.tmp/audit_report-2.md` section **"5. Issues / Suggestions (Severity-Rated)"** against the current code and tests.

## Overall Verdict
- **Status: Partial Pass**
- **Summary:** 3 remarks are fixed, 3 are partially fixed, 1 remains open.

## One-by-One Comparison

1. **[High] Notification rate limiting can fail open in service layer**
- Previous audit status: **Fail**
- Current status: **Fixed**
- Comparison:
  - Service now forces fail-closed on limiter errors (`error -> Coalesce`): `repo/Notifications/CMNotificationCenterService.m:118-123`
  - Background limiter uses injected limiter class (test error injectors now apply): `repo/Notifications/CMNotificationCenterService.m:93-96`
  - Added integration coverage for this exact negative path:
    - `CMErroringRateLimiter`: `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:20-35`
    - `testRateLimiterRepoErrorForcesCoalesce`: `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:466-514`

2. **[High] Biometric sign-in path does not verify biometric enrollment state**
- Previous audit status: **Fail**
- Current status: **Fixed (code), test gap remains**
- Comparison:
  - Login now requires `biometricEnabled == YES` and `biometricRefId == keychain key` before success:
    - `repo/Auth/CMAuthService.m:358-363`
  - Rejects biometric login when enrollment linkage is missing/mismatched:
    - `repo/Auth/CMAuthService.m:364-372`
  - Note: I did not find a dedicated integration test that asserts this specific enrollment-gating branch.

3. **[High] Account deletion service lacks tenant ownership validation of target object**
- Previous audit status: **Fail**
- Current status: **Fixed (code), partial test coverage**
- Comparison:
  - Explicit tenant-object guard now blocks cross-tenant delete attempts:
    - `repo/Admin/CMAccountService.m:49-50`
  - Denial is audited with actor/target tenant metadata:
    - `repo/Admin/CMAccountService.m:52-60`
  - Existing account deletion integration tests validate role/self-delete/double-delete paths, but there is no explicit cross-tenant delete test case in this file:
    - `repo/Tests/Integration/CMAccountDeletionIntegrationTests.m:24-184`

4. **[Medium] Notification tenant context is ambient and may be unset in async/background contexts**
- Previous audit status: **Partial Fail**
- Current status: **Partially Fixed**
- Comparison:
  - New explicit-tenant emission API exists (preferred for background paths):
    - `repo/Notifications/CMNotificationCenterService.h:51-60`
  - Service captures explicit tenant before background task and stamps records with it:
    - `repo/Notifications/CMNotificationCenterService.m:84-85`
    - `repo/Notifications/CMNotificationCenterService.m:132-136`
  - However, legacy overload still derives tenant from ambient context, and key call sites still use legacy overload:
    - ambient wrapper: `repo/Notifications/CMNotificationCenterService.m:63-67`
    - examples: `repo/Orders/CMOrderDetailViewController.m:153-159`, `repo/Orders/CMOrderDetailViewController.m:220-225`

5. **[Medium] Attachment allowlist configurability is partial (size only)**
- Previous audit status: **Partial Fail**
- Current status: **Partially Fixed**
- Comparison:
  - Admin UI now accepts MIME list updates and audits them:
    - `repo/Admin/CMAdminDashboardViewController.m:474-498`
    - `repo/Admin/CMAdminDashboardViewController.m:500-506`
  - But allowlist enforces intersection with hard-coded defaults (cannot expand beyond fixed MIME set):
    - `repo/Attachments/CMAttachmentAllowlist.m:44-49`
    - defaults still hard-coded: `repo/Attachments/CMAttachmentAllowlist.m:51-59`

6. **[Medium] Some integration tests use weak assertions that can mask regressions**
- Previous audit status: **Partial Fail**
- Current status: **Partially Fixed**
- Comparison:
  - Lockout assertion in auth integration test is now strict (`must be Locked`):
    - `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:288-300`
  - But weak "at least one action" OR-based assertion remains in dispute/appeal audit lifecycle test:
    - `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:249-253`

7. **[Low] Test command surface is split between native and Docker wrappers**
- Previous audit status: **Partial Fail**
- Current status: **Not Fixed**
- Comparison:
  - README still presents both Docker and native/local test paths:
    - Docker path: `repo/README.md:62-66`
    - Native test path via `run_tests.sh`: `repo/README.md:90-93`
  - Additional native command surface still exists in Makefile targets:
    - `repo/Makefile:31-55`

## Notes
- This is a **static code/test comparison** only; I did not execute tests in this pass.
