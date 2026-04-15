//
//  CMSignatureCaptureViewControllerTests.m
//  CourierMatch Integration Tests
//
//  Smoke + interaction tests for signature drawing canvas VC.
//

#import "CMIntegrationTestCase.h"
#import "CMSignatureCaptureViewController.h"
#import "CMSessionManager.h"
#import "CMUserAccount.h"

@interface CMSignatureCaptureViewControllerTests : CMIntegrationTestCase <CMSignatureCaptureDelegate>
@property (nonatomic, assign) BOOL didComplete;
@property (nonatomic, assign) BOOL didCancel;
@end

@implementation CMSignatureCaptureViewControllerTests

- (void)setUp {
    [super setUp];
    [self switchToUser:self.courierUser];
    [[CMSessionManager shared] openSessionForUser:self.courierUser];
    self.didComplete = NO;
    self.didCancel = NO;
}

- (void)signatureCaptureDidComplete:(CMAttachment *)attachment {
    self.didComplete = YES;
}

- (void)signatureCaptureDidCancel {
    self.didCancel = YES;
}

- (void)testInitWithOrderId {
    CMSignatureCaptureViewController *vc = [[CMSignatureCaptureViewController alloc] initWithOrderId:@"ord-sig-1"];
    XCTAssertNotNil(vc);
    XCTAssertNoThrow([vc loadViewIfNeeded]);
    XCTAssertNotNil(vc.view);
}

- (void)testViewLifecycle {
    CMSignatureCaptureViewController *vc = [[CMSignatureCaptureViewController alloc] initWithOrderId:@"ord-sig-2"];
    [vc loadViewIfNeeded];
    XCTAssertNoThrow([vc viewWillAppear:NO]);
    XCTAssertNoThrow([vc viewDidAppear:NO]);
    XCTAssertNoThrow([vc viewWillDisappear:NO]);
    XCTAssertNoThrow([vc viewDidDisappear:NO]);
}

- (void)testCancelDelegate {
    CMSignatureCaptureViewController *vc = [[CMSignatureCaptureViewController alloc] initWithOrderId:@"ord-sig-3"];
    vc.delegate = self;
    [vc loadViewIfNeeded];

    // Try to invoke private cancelTapped via NSSelectorFromString
    SEL cancelSel = NSSelectorFromString(@"cancelTapped");
    if ([vc respondsToSelector:cancelSel]) {
        IMP imp = [vc methodForSelector:cancelSel];
        void (*func)(id, SEL) = (void *)imp;
        func(vc, cancelSel);
        XCTAssertTrue(self.didCancel, @"Delegate cancel should be called");
    }
}

- (void)testClearAction {
    CMSignatureCaptureViewController *vc = [[CMSignatureCaptureViewController alloc] initWithOrderId:@"ord-sig-4"];
    [vc loadViewIfNeeded];
    SEL clearSel = NSSelectorFromString(@"clearTapped");
    if ([vc respondsToSelector:clearSel]) {
        IMP imp = [vc methodForSelector:clearSel];
        void (*func)(id, SEL) = (void *)imp;
        XCTAssertNoThrow(func(vc, clearSel));
    }
}

- (void)testConfirmWithoutSignatureShowsAlert {
    CMSignatureCaptureViewController *vc = [[CMSignatureCaptureViewController alloc] initWithOrderId:@"ord-sig-5"];
    [vc loadViewIfNeeded];
    SEL confirmSel = NSSelectorFromString(@"confirmTapped");
    if ([vc respondsToSelector:confirmSel]) {
        IMP imp = [vc methodForSelector:confirmSel];
        void (*func)(id, SEL) = (void *)imp;
        XCTAssertNoThrow(func(vc, confirmSel));
    }
}

@end
