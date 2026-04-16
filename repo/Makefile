# CourierMatch — Build & Test Automation
#
# Prerequisites: macOS with Xcode + XcodeGen installed.
# Run `make setup` first to generate the .xcodeproj.

SCHEME        = CourierMatch
PROJECT       = CourierMatch.xcodeproj
SIMULATOR     = iPhone 17 Pro
DESTINATION   = platform=iOS Simulator,name=$(SIMULATOR)
SIGN_FLAGS    = CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
                CODE_SIGNING_ALLOWED=YES AD_HOC_CODE_SIGNING_ALLOWED=YES \
                GENERATE_INFOPLIST_FILE=YES

.PHONY: setup build test test-unit test-integration test-ui run clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Generate .xcodeproj from project.yml (run once, or after adding files)
	xcodegen generate

build: setup ## Build the app for iOS Simulator
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' \
		$(SIGN_FLAGS) \
		| tail -5

test: setup ## Run all tests — canonical path is ./run_tests.sh
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:CourierMatchTests \
		$(SIGN_FLAGS) \
		| grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)' | tail -200

run: setup ## Build and launch on simulator
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		$(SIGN_FLAGS)
	@echo ""
	@echo "Installing on simulator..."
	@# Exclude Index.noindex — Xcode's indexer stub has no Info.plist/bundle ID
	@# and `simctl install` fails with "Missing bundle ID" if we pick it.
	@# Chain with && so failures surface instead of being masked by a
	@# spurious "App launched" message at the end of the recipe.
	@APP=$$(find ~/Library/Developer/Xcode/DerivedData -name "CourierMatch.app" -path "*/Build/Products/Debug-iphonesimulator/*" -not -path "*Index.noindex*" 2>/dev/null | head -1); \
	if [ -z "$$APP" ] || [ ! -f "$$APP/Info.plist" ]; then \
		echo "ERROR: Could not find a valid .app bundle (looked under */Build/Products/Debug-iphonesimulator/, excluding Index.noindex, requiring Info.plist)."; \
		exit 1; \
	fi; \
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true; \
	xcrun simctl terminate '$(SIMULATOR)' com.eaglepoint.couriermatch 2>/dev/null || true; \
	xcrun simctl uninstall '$(SIMULATOR)' com.eaglepoint.couriermatch 2>/dev/null || true; \
	xcrun simctl install '$(SIMULATOR)' "$$APP" && \
	xcrun simctl launch '$(SIMULATOR)' com.eaglepoint.couriermatch && \
	open -a Simulator && \
	echo "App launched on $(SIMULATOR)."

clean: ## Remove build artifacts and generated project
	rm -rf build/ DerivedData/
	rm -rf $(PROJECT)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
	@echo "Cleaned."
