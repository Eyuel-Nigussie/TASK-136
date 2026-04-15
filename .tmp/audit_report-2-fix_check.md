# CourierMatch Audit Fix Check (Static-Only)

## Verdict
- Overall: **Partial Pass (Improved)**
- Result: Both prior **High** issues appear fixed in code. Some coverage depth and biometric-binding hardening still remain partial.

## Scope Boundary
- Static-only re-check of previously reported issues.
- No app run, no tests executed, no Docker, no code changes made by reviewer.

## Fix Status by Prior Issue

### 1) High: On-the-way stops not used in matching
- Status: **Resolved (Static Evidence)**
- Evidence:
  - `repo/Match/CMMatchEngine.m:299` passes `itinerary.onTheWayStops` into scoring.
  - `repo/Match/CMMatchEngine.m:448` scoring method now accepts `onTheWayStops`.
  - `repo/Match/CMMatchEngine.m:461` onward implements stop-aware base-route + best insertion detour computation.
  - `repo/Match/CMMatchEngine.m:541` uses route-aware distance to pickup for ETA.
- Test evidence:
  - `repo/Tests/Integration/CMCourierFlowIntegrationTests.m:356` adds stop-aware integration test.

### 2) High: Notification read/ack audit was log-only
- Status: **Resolved (Static Evidence)**
- Evidence:
  - `repo/Notifications/CMNotificationCenterService.m:126` durable `notification.created` audit write.
  - `repo/Notifications/CMNotificationCenterService.m:228` durable `notification.read` audit write.
  - `repo/Notifications/CMNotificationCenterService.m:276` durable `notification.ack` audit write.
  - `repo/Notifications/CMNotificationCenterService.m:396`, `:415`, `:430`, `:439` digest/cascade audit writes.
- Test evidence:
  - `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:365` create->audit assertion.
  - `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:397` read->audit assertion.

### 3) Medium: UI-gated actions lacked function-level permission checks
- Status: **Resolved (Static Evidence)**
- Evidence:
  - `repo/Orders/CMOrderDetailViewController.m:250` permission gate in `capturePhotoTapped`.
  - `repo/Orders/CMOrderDetailViewController.m:264` permission gate in `captureSignatureTapped`.
  - `repo/Orders/CMOrderDetailViewController.m:298` permission gate in `editNotesTapped`.

### 4) Medium: Biometric identity binding via last userId only
- Status: **Partially Resolved**
- Evidence:
  - `repo/Auth/CMLoginViewController.m:363` reads stored userId and tenantId.
  - `repo/Auth/CMLoginViewController.m:375` enforces entered tenant mismatch rejection.
  - `repo/Auth/CMLoginViewController.m:420` persists `CMLastAuthenticatedTenantId` on success.
- Remaining concern:
  - Auth still signs in by stored `userId` without requiring username/account picker confirmation (`repo/Auth/CMAuthService.m:299`, `repo/Auth/CMAuthService.m:344`). This is improved but not fully explicit user-target confirmation.

### 5) Medium: Security test gaps (biometric/audit persistence)
- Status: **Partially Resolved**
- Evidence:
  - Biometric binding tests added: `repo/Tests/Unit/CMBiometricAuthTests.m:34`, `:51`, `:69`.
  - Notification audit tests added (create/read): `repo/Tests/Integration/CMNotificationCoalescingIntegrationTests.m:365`, `:397`.
- Remaining gap:
  - No explicit test found for `notification.ack` audit action persistence.

## Security Re-check Summary
- Authentication: **Partial Pass** (improved biometric tenant binding, still lacks explicit account-target confirmation UX).
- Function/object authorization: **Pass** for previously flagged order-detail handler gap.
- Tenant isolation: **Pass** (no regression observed in this fix check scope).
- Audit immutability for notification lifecycle: **Partial Pass** (implemented in code; tests currently cover create/read, not explicitly ack).

## Updated Conclusion
- The previously reported blockers/high-risk findings were addressed in code.
- Residual risk is now mainly in **coverage depth** and **biometric UX/account-target hardening**, not in the original core high defects.
