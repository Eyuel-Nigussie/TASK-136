#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
SUITE="${1:-all}"

echo "=== Running CourierMatch Tests (suite: ${SUITE}) ==="

# Ensure project exists
if [[ ! -d "CourierMatch.xcodeproj" ]]; then
    echo "  Generating Xcode project..."
    xcodegen generate
fi

# Boot simulator if needed
xcrun simctl boot "${SIMULATOR}" 2>/dev/null || true

BASE_CMD=(
    xcodebuild test
    -project CourierMatch.xcodeproj
    -scheme CourierMatch
    -destination "platform=iOS Simulator,name=${SIMULATOR}"
    CODE_SIGN_IDENTITY="-"
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=YES
    AD_HOC_CODE_SIGNING_ALLOWED=YES
    GENERATE_INFOPLIST_FILE=YES
)

case "${SUITE}" in
    all)
        "${BASE_CMD[@]}" -only-testing:CourierMatchTests 2>&1 | \
            grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)'
        ;;
    unit)
        "${BASE_CMD[@]}" \
            -only-testing:CourierMatchTests \
            -skip-testing:CourierMatchTests/CMAuthFlowIntegrationTests \
            -skip-testing:CourierMatchTests/CMCourierFlowIntegrationTests \
            -skip-testing:CourierMatchTests/CMDisputeAppealIntegrationTests \
            -skip-testing:CourierMatchTests/CMNotificationCoalescingIntegrationTests \
            -skip-testing:CourierMatchTests/CMAuditChainIntegrationTests \
            2>&1 | grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)'
        ;;
    integration)
        "${BASE_CMD[@]}" \
            -only-testing:CourierMatchTests/CMAuthFlowIntegrationTests \
            -only-testing:CourierMatchTests/CMCourierFlowIntegrationTests \
            -only-testing:CourierMatchTests/CMDisputeAppealIntegrationTests \
            -only-testing:CourierMatchTests/CMNotificationCoalescingIntegrationTests \
            -only-testing:CourierMatchTests/CMAuditChainIntegrationTests \
            2>&1 | grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)'
        ;;
    ui)
        "${BASE_CMD[@]}" -only-testing:CourierMatchUITests 2>&1 | \
            grep -E '(Test Suite|Test Case.*failed|Executed|BUILD)'
        ;;
    *)
        echo "Usage: $0 [all|unit|integration|ui]"
        exit 1
        ;;
esac
