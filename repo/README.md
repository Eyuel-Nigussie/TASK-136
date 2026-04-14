# CourierMatch -- iOS Operations & Audit App

Native iOS application (Objective-C / UIKit) for offline courier dispatching,
itinerary-based order matching, and compliant delivery performance scoring.

**240+ source files** | **~27,000 lines Objective-C** | **310+ test methods**

---

## Prerequisites

| Tool | Install | Required for |
|---|---|---|
| macOS 14+ + Xcode 16+ | Mac App Store | Native build, test, run (primary) |
| XcodeGen | `brew install xcodegen` | Generate .xcodeproj from project.yml |
| Docker (optional) | `brew install --cask docker` | Platform-independent validation |

---

## Native Build (Primary — macOS)

```bash
make setup       # Generate .xcodeproj via XcodeGen
make build       # Build for iOS Simulator
make test        # Run all XCTest tests
make run         # Launch on simulator
```

Or open in Xcode: `make setup && open CourierMatch.xcodeproj` then Cmd+R.

---

## Docker Commands (Optional Validation)

### All Commands

```
docker run couriermatch build       # Validate project (any platform)
docker run couriermatch test        # Validate tests (any platform)
docker run couriermatch run-mac     # Launch on simulator (macOS only)
docker run couriermatch test-mac    # Run XCTest suite (macOS only)
docker run couriermatch help        # Show all commands
```

### Docker Compose

```bash
docker compose run build
docker compose run test
docker compose run run-mac       # macOS only
docker compose run test-mac      # macOS only
```

### Build (works on Linux and macOS)

```bash
docker build -t couriermatch .
docker run couriermatch build
```

Validates project structure, source files, imports, Core Data model,
Info.plist configuration, and test suite. No Xcode required.

### Test (works on Linux and macOS)

```bash
docker run couriermatch test
```

Validates test file structure, counts test methods and assertions,
checks coverage breadth across all modules. On Linux, platform-dependent
tests (XCTest execution, iOS Simulator) are skipped automatically.
On macOS with Xcode, runs the full XCTest suite.

### Run App on Simulator (macOS only)

```bash
./scripts/docker-setup.sh                          # One-time setup
docker run -v "$(pwd):/app" couriermatch run-mac   # Build + launch on simulator
```

### Run Full XCTest Suite (macOS only)

```bash
./scripts/docker-setup.sh                           # One-time setup
docker run -v "$(pwd):/app" couriermatch test-mac   # Run full XCTest suite
```

---

## Project Structure

```
repo/
|-- Dockerfile              Docker build/test/run
|-- docker-compose.yml      Docker compose services
|-- Makefile                macOS build automation
|-- project.yml             XcodeGen spec (generates .xcodeproj)
|-- scripts/
|   |-- validate-build.py   Platform-independent build validation
|   |-- validate-tests.py   Platform-independent test validation
|   |-- docker-entrypoint.sh Docker command dispatcher
|   |-- docker-setup.sh     One-time macOS host setup (for run-mac/test-mac)
|   |-- bootstrap.sh        macOS dependency check
|   |-- build.sh            macOS xcodebuild wrapper
|   |-- test.sh             macOS XCTest runner
|   `-- run.sh              macOS simulator launcher
|
|-- App/                    AppDelegate, SceneDelegate, main.m, Info.plist
|-- Auth/                   Login, signup, hashing, lockout, CAPTCHA, biometrics
|-- Itinerary/              Itinerary entity, list/detail/form, import, location
|-- Orders/                 Order entity, list/detail with RBAC
|-- Match/                  Match engine, geo math, scoring, explanations
|-- Notifications/          Notification center, templates, rate limiter
|-- Scoring/                Scoring engine, auto-scorers, rubrics, scorecards
|-- Appeals/                Appeal service, dispute intake, appeal review
|-- Audit/                  Audit service, hash chain, meta-chain, verifier
|-- Attachments/            Attachment service, hashing, allowlist, camera
|-- Admin/                  Tenant, permission matrix, admin dashboard
|-- BackgroundTasks/        BGTaskScheduler manager, purge jobs
|-- Common/                 Errors, masking, normalization, theming, haptics
|-- Persistence/            Core Data, Keychain, file protection, repositories
|-- Resources/              LaunchScreen, templates, permission matrix
`-- Tests/
    |-- Unit/               22 files, ~242 test methods
    |-- Integration/        6+ files, ~30 test methods
    `-- UI/                 5 files, ~27 test methods
```

---

## Documentation

- `docs/design.md` -- System design document
- `docs/questions.md` -- 20 assumptions with concrete solutions
- `docs/apispec.md` -- API specification (no external APIs — fully offline)
