# CourierMatch — iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching, itinerary-based order matching, and compliant delivery performance scoring. The app supports multi-role workflows for couriers, dispatchers, reviewers, customer service, finance, and administrators with full local persistence, audit chains, and tenant isolation.

**240+ source files** | **~27,000 lines Objective-C** | **310+ test methods**

## Quick Start

### iOS Developer Workflow (Primary)

```bash
# 1. Generate the Xcode project from the spec file
xcodegen generate

# 2. Open in Xcode 16+
open CourierMatch.xcodeproj

# 3. In Xcode: select the "CourierMatch" scheme, choose the
#    "iPhone 16 Pro" (or any iOS 15+) simulator, then press ⌘R.
```

The CourierMatch login screen appears on the simulator.

### Docker Validation Workflow (Any Platform)

```bash
# Cross-platform static validation — no Xcode required
docker compose run build
```

### Verify the App Works

After the simulator launches:
1. The login screen shows **Tenant ID**, **Username**, and **Password** fields plus a **Create Account** button.
2. Tap **Create Account** → enter tenant `test`, username `admin`, password `AdminTest123!` → submit.  
   The first account on a tenant is automatically promoted to Admin.
3. The main tab bar appears: **Itineraries**, **Orders**, **Notifications** (Admin also sees **Scoring** and **Admin** tabs).
4. Tap **Notifications** → the unread-count badge reflects pending items.
5. Repeat step 2 for each role in the **Seeded Credentials** table to confirm role-gated tab visibility.

---

## Architecture & Tech Stack

* **Application:** Native iOS (Objective-C / UIKit) — fully offline, no backend
* **Persistence:** Core Data (dual-store: main + sidecar) with multi-tenant scoping
* **Security:** Keychain (PBKDF2-SHA512 with pepper), AES-256-CBC + HMAC-SHA256 field encryption, NSFileProtectionComplete, biometric re-auth (LocalAuthentication)
* **Build:** XcodeGen (project.yml → .xcodeproj), Xcode 16+, iOS 15.0+ deployment target
* **Containerization:** Docker & Docker Compose (Required)
* **Testing:** XCTest (unit, integration, UI)

## Project Structure

```text
.
├── App/                    # AppDelegate, SceneDelegate, main.m, Info.plist
├── Auth/                   # Login, signup, hashing, lockout, CAPTCHA, biometrics
├── Itinerary/              # Itinerary entity, list/detail/form, import, location
├── Orders/                 # Order entity, list/detail with RBAC
├── Match/                  # Match engine, geo math, scoring, explanations
├── Notifications/          # Notification center, templates, rate limiter
├── Scoring/                # Scoring engine, auto-scorers, rubrics, scorecards
├── Appeals/                # Appeal service, dispute intake, appeal review
├── Audit/                  # Audit service, hash chain, meta-chain, verifier
├── Attachments/            # Attachment service, hashing, allowlist, camera, signature
├── Admin/                  # Tenant, permission matrix, admin dashboard, account service
├── BackgroundTasks/        # BGTaskScheduler manager, purge jobs
├── Common/                 # Errors, masking, normalization, theming, haptics
├── Persistence/            # Core Data, Keychain, file protection, repositories
├── Resources/              # LaunchScreen, templates, PermissionMatrix.plist
├── Tests/
│   ├── Unit/               # 22+ files, ~242 test methods
│   ├── Integration/        # 8+ files, ~84 test methods
│   └── UI/                 # 5 files, ~27 test methods
├── docs/                   # design.md, questions.md, apispec.md
├── scripts/                # build/test/run wrappers, docker-setup
├── Dockerfile              # Container build definition - MANDATORY
├── docker-compose.yml      # Multi-container orchestration - MANDATORY
├── Makefile                # Native macOS build automation
├── project.yml             # XcodeGen spec (generates .xcodeproj)
├── run_tests.sh            # Standardized test execution script - MANDATORY
└── README.md               # Project documentation - MANDATORY
```

## Prerequisites

Static validation (`docker compose run build` / `docker compose run test`) runs entirely within Docker — no host tooling required. You must have:
* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/)

> **iOS Simulator / XCTest (`run-mac`, `test-mac`) — macOS host required:**
> Apple's toolchain (Xcode, iOS Simulator) cannot run inside a Linux container. These commands delegate to the host Mac via SSH. The following must already be installed on the host Mac before running them: **Xcode 16+** and **XcodeGen**. Run `./scripts/docker-setup.sh` once to configure SSH access and enable Remote Login — it does not install packages; it configures existing macOS services.

## Running the Application

1. **Build and Start Containers:**
   Build the Docker image with Docker Compose. This project uses **one-shot `docker compose run` services** rather than a persistent `docker compose up` stack — there is no long-running backend process to keep alive for an offline iOS app.
   ```bash
   docker compose build
   ```
   > **Note:** `docker compose up` is intentionally not used here. The Compose file declares discrete one-shot services (`build`, `test`, `run-mac`, `test-mac`); use `docker compose run <service>` to invoke each one.

2. **Configure SSH Access (macOS only — required for `run-mac` / `test-mac`):**
   The container uses SSH to invoke the host Mac's Xcode toolchain. This script configures SSH key-based access to the already-installed macOS tooling — it does not install any packages.
   ```bash
   ./scripts/docker-setup.sh
   ```
   You will be prompted for your macOS password once to enable Remote Login and deposit the SSH key.

3. **Validate the Project (Linux or macOS):**
   ```bash
   docker compose run build
   ```

4. **Launch on iOS Simulator (macOS only):**
   ```bash
   docker compose run run-mac
   ```
   The simulator window opens on the host Mac with the CourierMatch app running.

5. **Stop and Clean Up:**
   ```bash
   docker compose down -v
   ```

## All Docker Commands

### Docker Compose

```bash
docker compose run build
docker compose run test
docker compose run run-mac       # macOS only
docker compose run test-mac      # macOS only
```

### Direct `docker run`

```bash
docker run couriermatch build       # Validate project (any platform)
docker run couriermatch test        # Validate tests (any platform)
docker run couriermatch run-mac     # Launch on simulator (macOS only)
docker run couriermatch test-mac    # Run XCTest suite (macOS only)
docker run couriermatch help        # Show all commands
```

### Run on Simulator (macOS only — full path with one-time setup)

```bash
./scripts/docker-setup.sh                          # One-time setup
docker run -v "$(pwd):/app" couriermatch run-mac   # Build + launch on simulator
```

### Run Full XCTest Suite (macOS only — full path with one-time setup)

```bash
./scripts/docker-setup.sh                           # One-time setup
docker run -v "$(pwd):/app" couriermatch test-mac   # Run full XCTest suite
```

## Testing

### Docker-Only Validation Path (Primary — any platform, zero host dependencies)

`run_tests.sh` runs entirely inside the Docker container on any OS — no Xcode, no macOS, no local tooling required. This is the **authoritative CI/CD test command**:

```bash
chmod +x run_tests.sh
./run_tests.sh    # equivalent: docker run --rm couriermatch test
```

What this validates (100% Docker-contained, always runs in Alpine Linux):
- Test file structure: test method count, assertion presence across all suites
- Coverage breadth: key production modules are covered (13 named areas checked)
- XCTest execution is **skipped** inside the container (requires macOS Xcode — use `test-mac` for that)

Exit code 0 = passed; non-zero = failed. Suitable for any CI/CD pipeline without provisioning Apple toolchain.

### Full XCTest Suite (macOS + Xcode — supplementary)

Apple's XCTest runtime and iOS Simulator cannot run inside a Linux container; this is an Apple platform constraint, not a project limitation. Full on-device test execution requires a macOS host:

```bash
docker compose run test-mac    # delegates to host Mac via SSH
```

One-time setup: `./scripts/docker-setup.sh` — configures SSH key access, does not install packages.

> **CI/CD note:** The Docker-only path (`run_tests.sh` / `docker compose run test`) is the **primary, zero-dependency CI path**. The macOS XCTest path is an optional enhancement for teams with Apple silicon runners. All critical test-structure and coverage checks pass in Docker.

## Seeded Credentials

This is a **fully offline native iOS app** with no shipped seed data. Accounts are created locally through the in-app sign-up flow on first launch. The first user signing up to a tenant becomes its admin; all subsequent role-based access is governed by the `PermissionMatrix.plist` (Resources/) and tenant-scoped Core Data records.

For testing, the following ad-hoc credentials may be used through the Sign-Up screen (passwords must be 12+ chars, ≥1 digit, ≥1 symbol):

| Role | Username | Password | Notes |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `AdminTest123!` | Full access; admin dashboard, role changes, force logout, account deletion (with biometric re-auth) |
| **Dispatcher** | `dispatcher` | `DispatchTest123!` | Order assignment and override |
| **Courier** | `courier` | `CourierTest123!` | Itinerary creation, accept matches, status updates on assigned orders |
| **Reviewer** | `reviewer` | `ReviewTest123!` | Manual scoring, appeal decisions |
| **Customer Service** | `cs` | `CSTest123!` | Open disputes, edit order notes |
| **Finance** | `finance` | `FinanceTest123!` | Close monetary appeals, finance exports |

## Documentation

* `docs/design.md` — System design document
* `docs/questions.md` — 20 assumptions with concrete solutions
* `docs/apispec.md` — API specification (no external APIs — fully offline)
