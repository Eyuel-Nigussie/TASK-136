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

test: setup ## Run all tests (unit + integration)
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:CourierMatchTests \
		$(SIGN_FLAGS) \
		| grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)' | tail -40

test-unit: setup ## Run unit tests only
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:CourierMatchTests \
		-skip-testing:CourierMatchTests/CMAuthFlowIntegrationTests \
		-skip-testing:CourierMatchTests/CMCourierFlowIntegrationTests \
		-skip-testing:CourierMatchTests/CMDisputeAppealIntegrationTests \
		-skip-testing:CourierMatchTests/CMNotificationCoalescingIntegrationTests \
		-skip-testing:CourierMatchTests/CMAuditChainIntegrationTests \
		$(SIGN_FLAGS) \
		| grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)' | tail -40

test-integration: setup ## Run integration tests only
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:CourierMatchTests/CMAuthFlowIntegrationTests \
		-only-testing:CourierMatchTests/CMCourierFlowIntegrationTests \
		-only-testing:CourierMatchTests/CMDisputeAppealIntegrationTests \
		-only-testing:CourierMatchTests/CMNotificationCoalescingIntegrationTests \
		-only-testing:CourierMatchTests/CMAuditChainIntegrationTests \
		$(SIGN_FLAGS) \
		| grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)' | tail -40

test-ui: setup ## Run UI tests (requires booted simulator)
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-only-testing:CourierMatchUITests \
		$(SIGN_FLAGS) \
		| grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)' | tail -40

run: setup ## Build and launch on simulator
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		$(SIGN_FLAGS)
	@echo ""
	@echo "Installing on simulator..."
	@APP=$$(find ~/Library/Developer/Xcode/DerivedData -name "CourierMatch.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1) && \
		if [ -n "$$APP" ]; then \
			xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true; \
			xcrun simctl install '$(SIMULATOR)' "$$APP"; \
			xcrun simctl launch '$(SIMULATOR)' com.eaglepoint.couriermatch; \
			open -a Simulator; \
			echo "App launched on $(SIMULATOR)."; \
		else \
			echo "ERROR: Could not find built .app bundle."; \
			exit 1; \
		fi

clean: ## Remove build artifacts and generated project
	rm -rf build/ DerivedData/
	rm -rf $(PROJECT)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
	@echo "Cleaned."
