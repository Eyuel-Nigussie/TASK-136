# CourierMatch — iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching, itinerary-based order matching, and compliant delivery performance scoring. The app supports multi-role workflows for couriers, dispatchers, reviewers, customer service, finance, and administrators with full local persistence, audit chains, and tenant isolation.

**240+ source files** | **~27,000 lines Objective-C** | **850+ test methods**

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

* [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
* **macOS with Xcode 16+** and **XcodeGen** installed on the host Mac

This is a native iOS app — the Docker container delegates to the host Mac's Xcode toolchain via SSH. On non-macOS hosts, the commands detect this and exit with a clear message.

## Running the Application

1. **Build and launch on iOS Simulator:**
   ```bash
   docker compose run build
   ```
   On first run, the container automatically detects macOS, generates an SSH key, and configures host communication. If Remote Login is not yet enabled, it prints two one-time setup commands to run on your Mac — after that, every subsequent `docker compose run build` is fully automatic with zero manual steps.

2. **Stop and Clean Up:**
   ```bash
   docker compose down -v
   ```

## All Docker Commands

```bash
docker compose run build       # Build + launch on iOS Simulator
docker compose run run-mac     # Alias for build
docker compose run test-mac    # Run full XCTest suite on host Mac
```

All commands auto-detect the host platform. On non-macOS hosts, they exit with a message explaining that macOS with Xcode is required. SSH setup is automatic — keys are generated on first run.

## Testing

Run the full XCTest suite via the standardized test script:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Or directly via Docker Compose:

```bash
docker compose run test-mac
```

Both commands auto-detect macOS, verify SSH connectivity, then delegate to the host Mac's `xcodebuild test`. On non-macOS hosts, they exit with a message explaining that macOS with Xcode is required.

Exit code 0 = all tests passed; non-zero = failure. Suitable for CI/CD pipelines with macOS runners.

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
