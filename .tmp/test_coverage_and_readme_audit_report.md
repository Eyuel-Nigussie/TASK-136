# Test Coverage Audit

## Backend Endpoint Inventory

### Endpoint Discovery Result
- Declared API surface: **no HTTP API**.
- Evidence:
  - `repo/docs/apispec.md:7` (`- No REST APIs`)
  - `repo/docs/apispec.md:8` (`- No HTTP endpoints`)
  - `repo/docs/apispec.md:14` (`application does not make any network requests`)

### Resolved Endpoint Inventory (METHOD + PATH)
- **Total endpoints found: 0**
- Inventory: **none**

## API Test Mapping Table

| Endpoint (METHOD + PATH) | Covered | Test Type | Test Files | Evidence |
|---|---|---|---|---|
| _None (no HTTP endpoints exist)_ | N/A | N/A | N/A | `repo/docs/apispec.md:7-14` |

## API Test Classification

### 1) True No-Mock HTTP
- **None**
- Reason: no HTTP routes/endpoints exist.

### 2) HTTP with Mocking
- **None**
- Reason: no HTTP request-layer tests exist.

### 3) Non-HTTP (unit/integration/UI without HTTP)
- **73 test files total**, all non-HTTP.
- Static signal:
  - `test_methods`: **852**
  - `assertions`: **1681**

## Mock Detection Rules Check

### Findings
- Framework-style mocks (`jest.mock`, `vi.mock`, `sinon.stub`, OCM*) detected: **none**
- Custom test doubles found (unit scope):
  - `CMTestNotificationRepository` (`repo/Tests/Unit/CMNotificationRateLimiterTests.m:14-20`)
  - `CMPerBucketMockRepository` (`repo/Tests/Unit/CMNotificationRateLimiterTests.m:49-54`)
  - `CMCameraCaptureDelegateStub` (`repo/Tests/Unit/CMCameraCaptureViewControllerTests.m:16-27`)

## Coverage Summary

- Total endpoints: **0**
- Endpoints with HTTP tests: **0**
- Endpoints with true no-mock HTTP tests: **0**
- HTTP coverage: **N/A (0/0)**
- True API coverage: **N/A (0/0)**

## Unit Test Summary

### Unit Coverage Improvement (Observed)
- Strong new contract-style coverage added, including:
  - `CMViewControllerStateTests` (`repo/Tests/Integration/CMViewControllerStateTests.m`)
  - `CMAppDelegateTests` (`repo/Tests/Unit/CMAppDelegateTests.m`)
  - previously added `CMAutoScorerRegistryTests`, `CMAutoScorerEdgeCaseTests`, `CMCameraCaptureViewControllerTests`

### Modules Covered (broad)
- Controllers: expanded with state/contract tests in addition to smoke/exhaustive tests.
- Services: broad integration coverage (auth, notifications, audit, attachments, disputes/appeals).
- Repositories: broad method-level checks (`CMRepositoryMethodTests`).
- Auth/session/permissions: strong flow + edge coverage.

### Important Remaining Gaps / Weaknesses
- Prior key strictness gaps remain addressed:
  - Notification limit assertion is strict (`<=2`): `repo/Tests/Integration/CMNotificationServiceQueryTests.m:118`
  - Session preflight tests enforce branch correctness/no-session failure: `repo/Tests/Integration/CMSessionManagerExtendedTests.m:69-75`, `:83-84`
  - Camera private selector absence now explicitly skipped (`XCTSkip`) instead of silent pass: `repo/Tests/Unit/CMCameraCaptureViewControllerTests.m:122`, `:140`
- Residual risk:
  - Some legacy suites are still crash/smoke-oriented rather than strict behavioral contracts.

## API Observability Check

- Endpoint observability (method + path): **N/A** (no HTTP endpoints).
- Request/response observability for HTTP: **N/A**.
- Non-HTTP behavior observability: strong across service/repository/state assertions.

## Tests Check

### run_tests.sh compliance
- Docker-based test command present:
  - `repo/run_tests.sh:7` (`docker run --rm couriermatch test`)
- Result: **PASS** for Docker-based criterion.

### Success/failure/edge/auth validation depth
- Success paths: strong.
- Failure/error paths: strong.
- Edge cases: materially improved.
- Auth/permissions: strong.
- Integration boundaries: strong for offline in-process domain boundaries.

## Test Coverage Score (0–100)
- **92 / 100**

## Score Rationale
- Breadth and assertion density increased again (73 files, 852 tests, 1681 assertions).
- New state/contract tests improve quality beyond pure smoke coverage.
- Remaining deduction for static-only audit and residual smoke-heavy legacy suites.

## Key Gaps
- No HTTP/API contract layer exists (by design for offline iOS).
- 일부 legacy controller tests remain non-crash oriented.

## Confidence & Assumptions
- Confidence: **High** for static conclusions.
- Assumptions:
  - Static inspection only (no runtime execution or measured line/branch coverage).
  - Endpoint findings are based on docs + code structure (no HTTP server/router layer).

---

# README Audit

## Project Type Detection
- Declared project type: **iOS**
- Evidence:
  - `repo/README.md:1`
  - `repo/README.md:3`

## README Location Check
- Required file exists: `repo/README.md` → **PASS**

## Hard Gate Evaluation

### Formatting
- **PASS**

### Startup Instructions (iOS requirement)
- **PASS**
- Evidence:
  - iOS workflow: `repo/README.md:9-22`
  - Simulator path: `repo/README.md:154-159`

### Access Method
- **PASS**
- Evidence:
  - Xcode simulator steps: `repo/README.md:18-22`
  - `docker compose run test-mac` host path: `repo/README.md:183-185`

### Verification Method
- **PASS**
- Evidence:
  - explicit verification flow: `repo/README.md:31-39`

### Environment Rules (STRICT)
- **PARTIAL / STRICT-FAIL**
- Evidence:
  - README now accurately states Docker test path skips XCTest in container:
    - `repo/README.md:165-175`
  - Full XCTest path still requires host macOS/Xcode toolchain:
    - `repo/README.md:91-92`
    - `repo/README.md:179-185`
- Rationale:
  - Under strict interpretation (“everything Docker-contained”), full execution remains host-coupled.

### Demo Credentials (auth exists)
- **PASS**
- Evidence:
  - complete role credentials table: `repo/README.md:197-204`

## Engineering Quality Review

### Strengths
- Clear separation of Docker-only validation vs full host XCTest.
- Prior README behavior-claim mismatch is resolved.

### Weaknesses
- Strict all-Docker requirement is still not fully satisfiable for native iOS runtime/XCTest paths.

## High Priority Issues
- None.

## Medium Priority Issues
- Strict environment-rule interpretation remains partially unmet due to Apple toolchain dependency.

## Low Priority Issues
- None material.

## Hard Gate Failures
- **Environment Rules (STRICT): FAIL (strict interpretation)**

## README Verdict
- **PARTIAL PASS**

---

## Final Verdicts
- Test Coverage Audit Verdict: **HIGH (static), improved into low-90s quality band**
- README Audit Verdict: **PARTIAL PASS (only strict environment interpretation remains open)**
