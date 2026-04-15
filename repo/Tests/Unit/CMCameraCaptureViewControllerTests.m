//
//  CMCameraCaptureViewControllerTests.m
//  CourierMatch Unit Tests
//
//  Covers CMCameraCaptureViewController: initialization, view loading,
//  background colour, delegate assignment, and picker-cancel callback.
//

#import <XCTest/XCTest.h>
#import "CMCameraCaptureViewController.h"
#import "CMAttachment.h"

// ---------------------------------------------------------------------------
// Stub delegate — records which callbacks fired.
// ---------------------------------------------------------------------------
@interface CMCameraCaptureDelegateStub : NSObject <CMCameraCaptureDelegate>
@property (nonatomic, assign) BOOL didCancel;
@property (nonatomic, assign) BOOL didCapture;
@property (nonatomic, strong) CMAttachment *capturedAttachment;
@end

@implementation CMCameraCaptureDelegateStub
- (void)cameraCaptureDidCancel               { self.didCancel = YES; }
- (void)cameraCaptureDidCaptureAttachment:(CMAttachment *)attachment {
    self.didCapture = YES;
    self.capturedAttachment = attachment;
}
@end

// ---------------------------------------------------------------------------
@interface CMCameraCaptureViewControllerTests : XCTestCase
@end

@implementation CMCameraCaptureViewControllerTests

#pragma mark - Initialization

- (void)testInitWithOwnerType_ReturnsNonNil {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"order-001"];
    XCTAssertNotNil(vc);
}

- (void)testInitIsKindOfUIViewController {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"order-001"];
    XCTAssertTrue([vc isKindOfClass:[UIViewController class]]);
}

- (void)testInitWithNilOwnerType_DoesNotCrash {
    XCTAssertNoThrow([[CMCameraCaptureViewController alloc]
                      initWithOwnerType:nil ownerId:@"order-002"]);
}

- (void)testInitWithNilOwnerId_DoesNotCrash {
    XCTAssertNoThrow([[CMCameraCaptureViewController alloc]
                      initWithOwnerType:@"Order" ownerId:nil]);
}

- (void)testInitWithBothNil_DoesNotCrash {
    XCTAssertNoThrow([[CMCameraCaptureViewController alloc]
                      initWithOwnerType:nil ownerId:nil]);
}

#pragma mark - View Loading

- (void)testViewLoads_NotNil {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"order-003"];
    (void)vc.view; // trigger viewDidLoad
    XCTAssertNotNil(vc.view);
}

- (void)testViewBackgroundColor_IsSystemBackground {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"order-004"];
    (void)vc.view;
    XCTAssertEqualObjects(vc.view.backgroundColor, [UIColor systemBackgroundColor],
                          @"Background colour must be UIColor.systemBackgroundColor after viewDidLoad");
}

#pragma mark - Delegate

- (void)testDelegateCanBeAssigned {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"id-1"];
    CMCameraCaptureDelegateStub *stub = [[CMCameraCaptureDelegateStub alloc] init];
    vc.delegate = stub;
    XCTAssertEqual(vc.delegate, stub);
}

- (void)testDelegateIsWeakReference {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"id-2"];
    @autoreleasepool {
        CMCameraCaptureDelegateStub *stub = [[CMCameraCaptureDelegateStub alloc] init];
        vc.delegate = stub;
        XCTAssertNotNil(vc.delegate);
        // stub goes out of scope and is released — weak property should nil itself
    }
    XCTAssertNil(vc.delegate, @"delegate is weak — must nil out when the stub is deallocated");
}

#pragma mark - dismissSelf (private — exercises delegate cancel callback)

- (void)testDismissSelf_CallsDelegateCameraCaptureDidCancel {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"id-3"];
    CMCameraCaptureDelegateStub *stub = [[CMCameraCaptureDelegateStub alloc] init];
    vc.delegate = stub;
    (void)vc.view;

    SEL sel = NSSelectorFromString(@"dismissSelf");
    if (![vc respondsToSelector:sel]) {
        XCTSkip(@"dismissSelf private selector not found — test skipped, not vacuously passed");
        return;
    }
    XCTAssertNoThrow([vc performSelector:sel]);
    // cameraCaptureDidCancel is called synchronously before the animated dismiss
    XCTAssertTrue(stub.didCancel,
                  @"dismissSelf must synchronously call cameraCaptureDidCancel on the delegate");
}

- (void)testDismissSelf_NilDelegate_DoesNotCrash {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"id-4"];
    vc.delegate = nil;
    (void)vc.view;

    SEL sel = NSSelectorFromString(@"dismissSelf");
    if (![vc respondsToSelector:sel]) {
        XCTSkip(@"dismissSelf private selector not found — test skipped, not vacuously passed");
        return;
    }
    XCTAssertNoThrow([vc performSelector:sel],
                     @"dismissSelf with nil delegate must not crash (message to nil is safe)");
}

#pragma mark - imagePickerControllerDidCancel: (public UIImagePickerControllerDelegate)

- (void)testImagePickerControllerDidCancel_DoesNotCrash {
    CMCameraCaptureViewController *vc =
        [[CMCameraCaptureViewController alloc] initWithOwnerType:@"Order"
                                                         ownerId:@"id-5"];
    vc.delegate = nil;
    (void)vc.view;

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    // The method dispatches a dismiss+completion block. Verify no exception is thrown.
    XCTAssertNoThrow([vc imagePickerControllerDidCancel:picker]);

    // Let the main-queue completion block (if any) drain before the test ends.
    XCTestExpectation *settle = [self expectationWithDescription:@"main-queue settle"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [settle fulfill]; });
    [self waitForExpectationsWithTimeout:3.0 handler:nil];
}

@end
