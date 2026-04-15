# CourierMatch — iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching, itinerary-based order matching, and compliant delivery performance scoring. The app supports multi-role workflows for couriers, dispatchers, reviewers, customer service, finance, and administrators with full local persistence, audit chains, and tenant isolation.

**240+ source files** | **~27,000 lines Objective-C** | **310+ test methods**

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

To ensure a consistent environment, this project is designed to run entirely within containers. You must have the following installed:
* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/)

> **Note for iOS-specific commands (`run-mac`, `test-mac`):** The Dockerfile validates the project on any platform. To actually build/run the iOS app on the simulator or run the full XCTest suite, the container delegates to the host Mac via SSH. macOS hosts also need Xcode 16+, XcodeGen (`brew install xcodegen`), and Remote Login enabled — handled automatically by `./scripts/docker-setup.sh`.

## Running the Application

1. **Build and Start Containers:**
   Use Docker Compose to build the image. The Compose file declares one-shot services (`build`, `test`, `run-mac`, `test-mac`) rather than a long-running stack.
   ```bash
   docker compose build
   ```

2. **One-Time Host Setup (macOS only — for simulator/XCTest commands):**
   The container needs SSH access to the host Mac to invoke Xcode and the iOS Simulator.
   ```bash
   ./scripts/docker-setup.sh
   ```
   This enables Remote Login, generates an SSH key, and prepares the host. You will be prompted for your password once.

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

All unit and integration tests are executed via a single, standardized shell script. This script handles container orchestration for the test environment.

Make sure the script is executable, then run it:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

*Note: The `run_tests.sh` script outputs a standard exit code (`0` for success, non-zero for failure) for CI/CD integration. The script runs entirely within Docker — no local Python, Node, or Xcode dependencies are invoked from the host.*

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
