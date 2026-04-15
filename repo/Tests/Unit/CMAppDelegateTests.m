//
//  CMAppDelegateTests.m
//  CourierMatch Unit Tests
//
//  Strict behavioral tests for AppDelegate:
//  notification constant values, protocol conformance, and
//  applicationDidReceiveMemoryWarning: side-effects.
//

#import <XCTest/XCTest.h>
#import "AppDelegate.h"

@interface CMAppDelegateTests : XCTestCase
@end

@implementation CMAppDelegateTests

#pragma mark - Notification Constant Values

- (void)testCMCoreDataDidBecomeReadyNotification_IsNonNil {
    XCTAssertNotNil(CMCoreDataDidBecomeReadyNotification,
                    @"CMCoreDataDidBecomeReadyNotification must be a non-nil constant");
}

- (void)testCMMemoryPressureNotification_IsNonNil {
    XCTAssertNotNil(CMMemoryPressureNotification,
                    @"CMMemoryPressureNotification must be a non-nil constant");
}

- (void)testCMCoreDataDidBecomeReadyNotification_MatchesExpectedStringValue {
    // The constant must equal its string name for any observer using a literal
    // notification-name string to function correctly.
    XCTAssertEqualObjects(CMCoreDataDidBecomeReadyNotification,
                          @"CMCoreDataDidBecomeReadyNotification",
                          @"CMCoreDataDidBecomeReadyNotification constant must equal its string name");
}

- (void)testCMMemoryPressureNotification_MatchesExpectedStringValue {
    XCTAssertEqualObjects(CMMemoryPressureNotification,
                          @"CMMemoryPressureNotification",
                          @"CMMemoryPressureNotification constant must equal its string name");
}

- (void)testNotificationConstants_AreDistinct {
    XCTAssertNotEqualObjects(CMCoreDataDidBecomeReadyNotification,
                             CMMemoryPressureNotification,
                             @"The two notification constants must have distinct values to avoid observer collisions");
}

#pragma mark - Protocol Conformance

- (void)testAppDelegate_ConformsToUIApplicationDelegate {
    XCTAssertTrue([AppDelegate conformsToProtocol:@protocol(UIApplicationDelegate)],
                  @"AppDelegate must conform to UIApplicationDelegate");
}

- (void)testAppDelegate_IsSubclassOfUIResponder {
    XCTAssertTrue([AppDelegate isSubclassOfClass:[UIResponder class]],
                  @"AppDelegate must be a UIResponder subclass (required by UIApplicationDelegate)");
}

#pragma mark - applicationDidReceiveMemoryWarning: posts CMMemoryPressureNotification

- (void)testApplicationDidReceiveMemoryWarning_PostsCMMemoryPressureNotification {
    AppDelegate *delegate = [[AppDelegate alloc] init];
    __block BOOL received = NO;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:CMMemoryPressureNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *note) {
        received = YES;
    }];
    [delegate applicationDidReceiveMemoryWarning:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertTrue(received,
                  @"applicationDidReceiveMemoryWarning: must post CMMemoryPressureNotification "
                   "so caches (image cache, batch resizer) can flush");
}

- (void)testApplicationDidReceiveMemoryWarning_NotificationObjectIsNil {
    // Per design.md §13.2, the object is nil so all subscribers can observe
    // without filtering on a specific sender.
    AppDelegate *delegate = [[AppDelegate alloc] init];
    __block id capturedObject = @"sentinel";  // non-nil sentinel; must become nil
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:CMMemoryPressureNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *note) {
        capturedObject = note.object;
    }];
    [delegate applicationDidReceiveMemoryWarning:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertNil(capturedObject,
                 @"applicationDidReceiveMemoryWarning: must post with nil object "
                  "so any observer can receive it without sender filtering");
}

- (void)testApplicationDidReceiveMemoryWarning_CalledTwice_PostsTwice {
    // Verify there is no one-shot guard; every warning must be broadcast.
    AppDelegate *delegate = [[AppDelegate alloc] init];
    __block NSUInteger callCount = 0;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:CMMemoryPressureNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *note) {
        callCount++;
    }];
    [delegate applicationDidReceiveMemoryWarning:nil];
    [delegate applicationDidReceiveMemoryWarning:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertEqual(callCount, 2u,
                   @"Each memory warning must post exactly one notification; "
                    "calling twice must produce two posts (no one-shot guard)");
}

@end
