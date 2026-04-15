//
//  CMHapticsTests.m
//  CourierMatch Tests
//
//  Smoke tests verifying haptic API entry points run without crashing.
//  UIFeedbackGenerator no-ops on devices without a Taptic Engine, so
//  these calls just need to not throw.
//

#import <XCTest/XCTest.h>
#import "CMHaptics.h"

@interface CMHapticsTests : XCTestCase
@end

@implementation CMHapticsTests

- (void)testSuccessHapticDoesNotCrash {
    XCTAssertNoThrow([CMHaptics success]);
}

- (void)testErrorHapticDoesNotCrash {
    XCTAssertNoThrow([CMHaptics error]);
}

- (void)testWarningHapticDoesNotCrash {
    XCTAssertNoThrow([CMHaptics warning]);
}

- (void)testSelectionChangedHapticDoesNotCrash {
    XCTAssertNoThrow([CMHaptics selectionChanged]);
}

- (void)testRapidSequentialCallsDoNotCrash {
    for (int i = 0; i < 10; i++) {
        [CMHaptics success];
        [CMHaptics error];
        [CMHaptics warning];
        [CMHaptics selectionChanged];
    }
    XCTAssertTrue(YES, @"Rapid haptic calls should not crash");
}

@end
