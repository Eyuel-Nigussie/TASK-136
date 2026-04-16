# Audit Report 2 - Fix Check (Item-by-Item)

## Scope Checked
Compared every original remark in `.tmp/audit_report-2.md` section **"5. Issues / Suggestions (Severity-Rated)"** against the current codebase and tests.

## Overall Verdict
- **Status: Pass**
- **Summary:** All previously reported `Fail` and `Partial Fail` items are addressed.

## One-by-One Comparison

1. **[High] Notification rate limiting can fail open in service layer**
- Previous audit status: **Fail**
- Current status: **Fixed**
- Comparison:
  - Service now forces fail-closed on limiter errors (`error -> Coalesce`): `repo/Notifications/CMNotificationCenterService.m:101-107`
  - Coalescing path is exercised by integration coverage:
    - `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:467-518`

2. **[High] Biometric sign-in path does not verify biometric enrollment state**
- Previous audit status: **Fail**
- Current status: **Fixed**
- Comparison:
  - Login now requires `biometricEnabled == YES` and `biometricRefId == keychain key` before success:
    - `repo/Auth/CMAuthService.m:361-373`
  - Dedicated integration coverage exists for disabled, mismatched, and nil ref-id branches:
    - `repo/Tests/Integration/CMBiometricEnrollmentGateTests.m:70-125`
    - `repo/Tests/Integration/CMBiometricEnrollmentGateTests.m:127-187`

3. **[High] Account deletion service lacks tenant ownership validation of target object**
- Previous audit status: **Fail**
- Current status: **Fixed**
- Comparison:
  - Explicit tenant guard now blocks cross-tenant delete attempts:
    - `repo/Admin/CMAccountService.m:49-66`
  - Denial is audited with actor/target tenant metadata:
    - `repo/Admin/CMAccountService.m:52-60`
  - Cross-tenant and nil-tenant negative integration tests now exist:
    - `repo/Tests/Integration/CMAccountDeletionIntegrationTests.m:188-222`

4. **[Medium] Notification tenant context is ambient and may be unset in async/background contexts**
- Previous audit status: **Partial Fail**
- Current status: **Fixed**
- Comparison:
  - Notification service API now requires explicit `tenantId`:
    - `repo/Notifications/CMNotificationCenterService.h:38-51`
  - Background emit path uses explicit tenant for limiter/bucketing and persisted items:
    - `repo/Notifications/CMNotificationCenterService.m:93-119`
  - Callers now pass explicit tenant IDs at emission sites:
    - `repo/Orders/CMOrderDetailViewController.m:151-162`
    - `repo/Orders/CMOrderDetailViewController.m:223-230`
    - `repo/Appeals/CMDisputeIntakeViewController.m:275-286`

5. **[Medium] Attachment allowlist configurability is partial (size only)**
- Previous audit status: **Partial Fail**
- Current status: **Fixed**
- Comparison:
  - Allowlist setter now accepts admin-configured MIME set directly (supports narrow/expand):
    - `repo/Attachments/CMAttachmentAllowlist.m:38-48`
  - Admin UI supports MIME list edits and audits config changes:
    - `repo/Admin/CMAdminDashboardViewController.m:474-506`

6. **[Medium] Some integration tests use weak assertions that can mask regressions**
- Previous audit status: **Partial Fail**
- Current status: **Fixed**
- Comparison:
  - Lockout path now asserts strict locked outcome:
    - `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:288-300`
  - Appeal lifecycle audit now asserts all required actions explicitly:
    - `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:247-260`

7. **[Low] Test command surface is split between native and Docker wrappers**
- Previous audit status: **Partial Fail**
- Current status: **Fixed**
- Comparison:
  - README now defines one canonical test command (`run_tests.sh`) and explicitly marks Docker validation as secondary:
    - `repo/README.md:78-87`

## Final Assessment
- All items originally marked as `Fail` or `Partial Fail` in `.tmp/audit_report-2.md` are now addressed in current code/tests/docs.
- Updated static acceptance result for this fix check: **Pass**.

## Notes
- This is a **static verification pass** (code + test inspection). I did not execute the XCTest suite in this check.
