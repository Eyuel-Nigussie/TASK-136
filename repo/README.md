# CourierMatch — iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching, itinerary-based order matching, and compliant delivery performance scoring. The app supports multi-role workflows for couriers, dispatchers, reviewers, customer service, finance, and administrators with full local persistence, audit chains, and tenant isolation.

**240+ source files** | **~27,000 lines Objective-C** | **850+ test methods**

## Quick Start

### Run the App

```bash
./start.sh
```

Builds the project, installs it on the iOS Simulator, and launches it. The CourierMatch login screen appears on the simulator.

### Run Tests

```bash
./run_tests.sh              # all tests (unit + integration)
./run_tests.sh unit         # unit tests only
./run_tests.sh integration  # integration tests only
./run_tests.sh ui           # UI tests only
```

### Docker Validation (Any Platform)

```bash
docker compose run build
```

Runs platform-independent project structure and test coverage validation inside Docker. No Xcode required.

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
* **Containerization:** Docker & Docker Compose (validation only)
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
├── scripts/                # build/test/run wrappers, validation scripts
├── start.sh                # Launch app locally on iOS Simulator - MANDATORY
├── Dockerfile              # Container build definition - MANDATORY
├── docker-compose.yml      # Docker validation service - MANDATORY
├── Makefile                # Native macOS build automation
├── project.yml             # XcodeGen spec (generates .xcodeproj)
├── run_tests.sh            # Standardized test execution script - MANDATORY
└── README.md               # Project documentation - MANDATORY
```

## Prerequisites

* **macOS with Xcode 16+** and **XcodeGen** (`brew install xcodegen`)
* [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) (for validation only)

## Running the Application

```bash
./start.sh
```

Builds the project, installs it on the iOS Simulator (iPhone 17 Pro by default), and launches it. Override the simulator with `SIMULATOR="iPhone 16 Pro" ./start.sh`.

## Testing

Run the full XCTest suite locally:

```bash
./run_tests.sh              # all tests (unit + integration)
./run_tests.sh unit         # unit tests only
./run_tests.sh integration  # integration tests only
./run_tests.sh ui           # UI tests only
```

Exit code 0 = all tests passed; non-zero = failure. Suitable for CI/CD pipelines with macOS runners.

## Docker

Docker is used only for platform-independent validation (no Xcode required):

```bash
docker compose run build
```

This runs `validate-build.py` (project structure) and `validate-tests.py` (test coverage) inside a lightweight Alpine container.

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
