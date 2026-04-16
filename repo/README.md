# CourierMatch

Native iOS application (Objective-C / UIKit) for offline courier dispatching, itinerary-based order matching, and compliant delivery performance scoring. The app supports multi-role workflows for couriers, dispatchers, reviewers, customer service, finance, and administrators with full local persistence, audit chains, and tenant isolation.

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

* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/)
* **macOS with Xcode 16+** and **XcodeGen** (`brew install xcodegen`)

## Running the Application

1. **Start the App:**
   ```bash
   ./start.sh
   ```
   Builds the project, installs it on the iOS Simulator (iPhone 17 Pro by default), and launches it.

2. **Access the App:**
   The CourierMatch login screen appears automatically after `./start.sh` completes.

3. **Verify the App Works:**
   1. The login screen shows **Tenant ID**, **Username**, and **Password** fields plus a **Create Account** button.
   2. Tap **Create Account** → enter tenant `test`, username `admin`, password `AdminTest123!` → submit. The first account on a tenant is automatically promoted to Admin.
   3. The main tab bar appears: **Itineraries**, **Orders**, **Notifications** (Admin also sees **Scoring** and **Admin** tabs).
   4. Tap **Notifications** → the unread-count badge reflects pending items.

4. **Stop and Clean Up:**
   ```bash
   docker compose down -v
   ```

## Testing

The **single canonical test command** is `run_tests.sh`. All unit, integration, and UI tests are executed through this script:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

This runs the full XCTest suite (850+ tests) via `xcodebuild test` on the local macOS host. Exit code 0 = all tests passed; non-zero = failure.

> **Docker validation** (`docker compose run build`) is secondary tooling that performs static project structure and test coverage checks inside an Alpine container. It does not execute XCTest and is not the canonical test path. Makefile targets (`make test`, `make test-unit`, etc.) are developer convenience wrappers around the same `xcodebuild` invocation and are not required for acceptance validation.

## Seeded Credentials

This is a fully offline native iOS app with no shipped seed data. Accounts are created locally through the in-app sign-up flow on first launch. The first user signing up to a tenant becomes its admin.

For testing, use the following credentials through the Sign-Up screen (passwords must be 12+ chars, with at least 1 digit and 1 symbol):

| Role | Username | Password | Notes |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `AdminTest123!` | Full access; admin dashboard, role changes, force logout, account deletion (with biometric re-auth) |
| **Dispatcher** | `dispatcher` | `DispatchTest123!` | Order assignment and override |
| **Courier** | `courier` | `CourierTest123!` | Itinerary creation, accept matches, status updates on assigned orders |
| **Reviewer** | `reviewer` | `ReviewTest123!` | Manual scoring, appeal decisions |
| **Customer Service** | `cs` | `CSTest123!` | Open disputes, edit order notes |
| **Finance** | `finance` | `FinanceTest123!` | Close monetary appeals, finance exports |
