# CourierMatch -- iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching,
itinerary-based order matching, and compliant delivery performance scoring.

**238 source files** | **~27,000 lines Objective-C** | **299 test methods**

---

## Prerequisites

| Tool | Install | Purpose |
|---|---|---|
| macOS 14+ | -- | Required OS for iOS development |
| Xcode 15+ | Mac App Store | Compiler, iOS SDK, Simulator |
| XcodeGen | `brew install xcodegen` | Generates .xcodeproj from project.yml |
| Docker Desktop | `brew install --cask docker` | Containerized build/test/run |

---

## Docker Setup (one-time)

```bash
./scripts/docker-setup.sh
```

This enables Remote Login (SSH), generates a Docker SSH key, and builds
the Docker image. You will be prompted for your password once.

---

## Build the App

```bash
docker run -v "$(pwd):/app" couriermatch build
```

## Run All Tests

```bash
docker run -v "$(pwd):/app" couriermatch test
```

## Run Unit Tests Only

```bash
docker run -v "$(pwd):/app" couriermatch test-unit
```

## Run Integration Tests Only

```bash
docker run -v "$(pwd):/app" couriermatch test-integration
```

## Run UI Tests

```bash
docker run -v "$(pwd):/app" couriermatch test-ui
```

## Launch on Simulator

```bash
docker run -v "$(pwd):/app" couriermatch run
```

## All Docker Commands

```
docker run -v "$(pwd):/app" couriermatch build             # Build for iOS Simulator
docker run -v "$(pwd):/app" couriermatch test              # Run all 299 tests
docker run -v "$(pwd):/app" couriermatch test-unit         # Unit tests only
docker run -v "$(pwd):/app" couriermatch test-integration  # Integration tests only
docker run -v "$(pwd):/app" couriermatch test-ui           # UI tests
docker run -v "$(pwd):/app" couriermatch run               # Build + launch on simulator
docker run -v "$(pwd):/app" couriermatch setup             # Generate .xcodeproj
docker run -v "$(pwd):/app" couriermatch clean             # Remove build artifacts
docker run -v "$(pwd):/app" couriermatch help              # Show commands
```

With docker-compose:

```bash
docker compose run build
docker compose run test
docker compose run test-unit
docker compose run test-integration
docker compose run app-run
```

---

## Without Docker

```bash
make setup       # Generate .xcodeproj
make build       # Build for iOS Simulator
make test        # Run all tests
make run         # Launch on simulator
```

Or open in Xcode:

```bash
make setup
open CourierMatch.xcodeproj    # Then Cmd+R
```

---

## Project Structure

```
repo/
|-- Dockerfile              Docker build definition
|-- docker-compose.yml      Docker compose services
|-- Makefile                Build/test/run automation
|-- project.yml             XcodeGen spec (generates .xcodeproj)
|-- courier                 CLI tool (./courier build, test, run)
|-- scripts/
|   |-- docker-setup.sh     One-time Docker setup
|   |-- docker-entrypoint.sh Docker command dispatcher
|   |-- bootstrap.sh        Check deps, generate project
|   |-- build.sh            Build the app
|   |-- test.sh             Run tests (all|unit|integration|ui)
|   `-- run.sh              Build + launch on simulator
|
|-- App/                    AppDelegate, SceneDelegate, main.m, Info.plist
|-- Auth/                   Login, signup, password hashing, lockout, CAPTCHA,
|                           biometrics, session manager, biometric enrollment
|-- Itinerary/              Itinerary entity, list/detail/form VCs
|-- Orders/                 Order entity, list/detail VCs with RBAC
|-- Match/                  Match engine, geo math, scoring weights,
|                           explanation strings, metro ZIP table
|-- Notifications/          Notification center, template renderer,
|                           rate limiter, notification list VC
|-- Scoring/                Scoring engine, auto-scorer registry, 3 built-in
|                           scorers, rubric templates, scorecards
|-- Appeals/                Appeal service, dispute intake, appeal review VC
|-- Audit/                  Audit service, hash chain, meta-chain, verifier,
|                           permission change auditor
|-- Attachments/            Attachment service, hashing service, allowlist,
|                           cleanup job, camera capture VC
|-- Admin/                  Tenant entity, permission matrix, admin dashboard
|-- BackgroundTasks/        BGTaskScheduler manager, notification purge job
|-- Common/                 Errors, masking, normalization, theming, haptics,
|                           accessibility helpers
|-- Persistence/            Core Data stack (dual-store), Keychain, file
|                           locations, 12 concrete repositories
|-- Resources/              LaunchScreen, templates, permission matrix plist
`-- Tests/
    |-- Unit/               22 files, ~242 test methods
    |-- Integration/        6 files, ~30 test methods
    `-- UI/                 5 files, ~27 test methods
```

---

## Key Design Decisions

- **Fully offline** -- no APIs, no servers, no networking
- **Multi-tenant** -- `tenantId` on every Core Data row; scoped automatically
- **Dual Core Data stores** -- main (NSFileProtectionComplete) + sidecar
  for background tasks
- **PBKDF2-SHA512** at 600k iterations with Keychain pepper
- **AES-256-CBC + HMAC-SHA256** for field-level encryption
- **Append-only audit trail** with per-tenant HMAC-SHA256 hash chains
- **In-app notification center only** -- no push, no system notifications
- **RBAC enforcement** -- CMPermissionMatrix + object-level authorization

---

## Documentation

- `docs/design.md` -- System design document
- `docs/questions.md` -- 20 assumptions with concrete solutions

---

## Clean Up

```bash
docker run -v "$(pwd):/app" couriermatch clean
docker compose down -v
```
