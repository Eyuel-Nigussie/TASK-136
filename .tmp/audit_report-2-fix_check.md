# Audit Report 2 - Fix Check

## Scope Checked
I reviewed the prior remark about **notification rate limiting fail-open behavior** from `.tmp/audit_report-2.md` and validated the current implementation and related tests.

## Verdict
- **Status: Fixed (for this remark)**

## What I Verified
1. **Service no longer fail-opens on limiter errors**
- In `CMNotificationCenterService`, limiter errors are explicitly converted to `CMRateLimitDecisionCoalesce` (fail-closed) instead of allowing notification emission as active.
- Evidence: `repo/Notifications/CMNotificationCenterService.m:118-123`

2. **Injected test limiter now actually affects background path**
- The service instantiates the background limiter using `[[self.rateLimiter class] ...]`, so test subclasses (error injectors) are respected in background execution.
- Evidence: `repo/Notifications/CMNotificationCenterService.m:93-96`

3. **Integration test added for the exact negative path**
- Added `CMErroringRateLimiter` test helper that returns `Allow` plus an error.
- Added `testRateLimiterRepoErrorForcesCoalesce`, asserting persisted notifications become `Coalesced` when limiter errors occur.
- Evidence: `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:20-35`, `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:466-514`

## Notes
- This check is a **static code/test review**; I did not execute the test suite in this pass.
- Other unrelated remarks from the original audit (biometric enrollment gating, tenant-object guard in account deletion, etc.) were not part of this specific fix verification and appear unchanged in current modified files.
