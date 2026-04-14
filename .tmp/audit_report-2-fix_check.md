# Audit Report 2 Fix Check

Checked on: 2026-04-14
Source audited: `.tmp/audit_report-2.md`

## Overall
- Result: **Partially Addressed**
- Findings fully addressed: **3 / 6**
- Findings partially addressed: **3 / 6**
- Findings not addressed: **0 / 6**

## Finding-by-finding status

### 1) Missing account deletion feature despite explicit requirement
- Status: **Partially Addressed**
- What is now present:
  - Account Deletion section in admin UI: `repo/Admin/CMAdminDashboardViewController.m:498`
  - Delete action wired: `repo/Admin/CMAdminDashboardViewController.m:620`
  - Biometric re-auth before delete: `repo/Admin/CMAdminDashboardViewController.m:330`
  - Soft-delete (`status=deleted`, `deletedAt`) + force logout: `repo/Admin/CMAdminDashboardViewController.m:352`
  - Audit event for deletion: `repo/Admin/CMAdminDashboardViewController.m:363`
- Remaining gap:
  - No dedicated tests found for account deletion + biometric re-auth flow.
  - Deletion logic is implemented in controller, not a dedicated service/repository path as suggested in the original minimum fix guidance.

### 2) Reviewer assignment lacks reviewer-role and tenant validation
- Status: **Addressed**
- Evidence:
  - Reviewer lookup added: `repo/Appeals/CMAppealService.m:133`
  - Reject non-existent target user: `repo/Appeals/CMAppealService.m:136`
  - Enforce reviewer-eligible roles: `repo/Appeals/CMAppealService.m:147`
  - Tenant scoping is enforced by repository fetch path (`fetchOneWithPredicate` uses scoped fetch):
    - `repo/Persistence/Repositories/CMUserRepository.m:22`
    - `repo/Persistence/Repositories/CMRepository.m:33`
- Test coverage added:
  - Reject courier target: `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:442`
  - Reject non-existent user: `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:462`

### 3) Dispute intake authorization is controller-only (no service-level guard)
- Status: **Addressed**
- Evidence:
  - Dispute intake VC now calls service to create dispute: `repo/Appeals/CMDisputeIntakeViewController.m:242`
  - Service has auth + role checks: `repo/Appeals/CMDisputeService.m:37`, `repo/Appeals/CMDisputeService.m:47`
- Test coverage added:
  - Service authorization tests for allowed/denied roles: `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:501`, `repo/Tests/Integration/CMDisputeAppealIntegrationTests.m:526`

### 4) Unscoped order fetch in scoring upgrade helper
- Status: **Addressed**
- Evidence:
  - Helper now uses `CMOrderRepository findByOrderId:`: `repo/Scoring/CMScoringEngine.m:593`
  - Repository calls scoped fetch path: `repo/Persistence/Repositories/CMOrderRepository.m:13`, `repo/Persistence/Repositories/CMRepository.m:55`

### 5) Prompt-fit ambiguity in signup semantics for non-courier roles
- Status: **Partially Addressed**
- What improved:
  - Policy is explicit in code/comments and enforced in service:
    - `repo/Auth/CMSignupViewController.m:75`
    - `repo/Auth/CMAuthService.m:67`
  - Integration tests verify restriction behavior:
    - `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:392`
    - `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:444`
    - `repo/Tests/Integration/CMAuthFlowIntegrationTests.m:466`
- Remaining gap:
  - Public docs still do not clearly state this policy (README/design mention signup generally, but not the courier-only self-signup rule).

### 6) Documentation/test-count inconsistencies
- Status: **Partially Addressed**
- What improved:
  - Previous explicit contradiction noted in audit (`299` vs `231`) is no longer present.
- Remaining gap:
  - README still has potentially inconsistent approximations:
    - Header: `310+ test methods` at `repo/README.md:6`
    - Section breakdown: `~242` + `~30` + `~27` (about `~299`) at `repo/README.md:130`

## Final acceptance check
- High-risk authorization/scoping findings from audit report 2 are now addressed in code.
- Delivery is improved materially, but full closure against the original fix guidance still needs:
  1. Account deletion test coverage (biometric re-auth success/failure + audit assertions)
  2. Clear signup-policy documentation
  3. One source-of-truth alignment for README test counts
