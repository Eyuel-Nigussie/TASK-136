//
//  CMNotificationTemplateRendererTests.m
//  CourierMatch Tests
//
//  Tests for notification template rendering: placeholder resolution,
//  missing variables, tenant overrides, and partial overrides.
//

#import <XCTest/XCTest.h>
#import "CMNotificationTemplateRenderer.h"

// ---------------------------------------------------------------------------
// A testable subclass that overrides the bundled templates with known values
// instead of loading from the main bundle plist.
// ---------------------------------------------------------------------------
@interface CMTestTemplateRenderer : CMNotificationTemplateRenderer
@end

@implementation CMTestTemplateRenderer

- (instancetype)init {
    if ((self = [super init])) {
        // Override the bundled templates with known test data.
        [self setValue:@{
            @"assigned": @{
                @"title": @"Order {orderRef} assigned",
                @"body":  @"Your order {orderRef} has been assigned to courier {courierName}."
            },
            @"delivered": @{
                @"title": @"Delivery Complete",
                @"body":  @"Order {orderRef} delivered at {time}."
            },
            @"multi": @{
                @"title": @"{a} and {b}",
                @"body":  @"Values: {a}, {b}, {c}"
            }
        } forKey:@"bundledTemplates"];
    }
    return self;
}

@end

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@interface CMNotificationTemplateRendererTests : XCTestCase
@property (nonatomic, strong) CMTestTemplateRenderer *renderer;
@end

@implementation CMNotificationTemplateRendererTests

- (void)setUp {
    [super setUp];
    self.renderer = [[CMTestTemplateRenderer alloc] init];
}

#pragma mark - Renders {orderRef} Placeholder with Value

- (void)testRendersOrderRefPlaceholder {
    NSDictionary *payload = @{@"orderRef": @"ORD-12345"};
    CMRenderedNotification *result = [self.renderer renderTemplateForKey:@"assigned"
                                                                payload:payload
                                                       tenantConfigJSON:nil];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.title, @"Order ORD-12345 assigned",
        @"orderRef placeholder should be replaced with payload value");
}

#pragma mark - Missing Variable -> "[n/a]"

- (void)testMissingVariableRendersNA {
    // Payload is missing "courierName"
    NSDictionary *payload = @{@"orderRef": @"ORD-999"};
    CMRenderedNotification *result = [self.renderer renderTemplateForKey:@"assigned"
                                                                payload:payload
                                                       tenantConfigJSON:nil];

    XCTAssertNotNil(result);
    XCTAssertTrue([result.body containsString:@"[n/a]"],
        @"Missing variable should render as [n/a], got: %@", result.body);
}

#pragma mark - Multiple Placeholders Resolved in One Pass

- (void)testMultiplePlaceholdersResolvedInOnePass {
    NSDictionary *payload = @{@"a": @"Alpha", @"b": @"Beta", @"c": @"Gamma"};
    CMRenderedNotification *result = [self.renderer renderTemplateForKey:@"multi"
                                                                payload:payload
                                                       tenantConfigJSON:nil];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.title, @"Alpha and Beta",
        @"Both {a} and {b} should be resolved in title");
    XCTAssertEqualObjects(result.body, @"Values: Alpha, Beta, Gamma",
        @"All three placeholders should be resolved in body");
}

#pragma mark - Tenant Config Override Replaces Bundled Template

- (void)testTenantConfigOverrideReplacesBundledTemplate {
    NSDictionary *tenantConfig = @{
        @"templates": @{
            @"assigned": @{
                @"title": @"CUSTOM: {orderRef}",
                @"body":  @"Custom body for {orderRef}."
            }
        }
    };
    NSDictionary *payload = @{@"orderRef": @"ORD-555"};
    CMRenderedNotification *result = [self.renderer renderTemplateForKey:@"assigned"
                                                                payload:payload
                                                       tenantConfigJSON:tenantConfig];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.title, @"CUSTOM: ORD-555",
        @"Tenant override title should be used instead of bundled");
    XCTAssertEqualObjects(result.body, @"Custom body for ORD-555.",
        @"Tenant override body should be used instead of bundled");
}

#pragma mark - Partial Tenant Override (Only Body) Inherits Title from Bundled

- (void)testPartialTenantOverrideInheritsTitleFromBundled {
    NSDictionary *tenantConfig = @{
        @"templates": @{
            @"assigned": @{
                @"body": @"Overridden body only for {orderRef}."
                // No "title" key: should fall back to bundled title.
            }
        }
    };
    NSDictionary *payload = @{@"orderRef": @"ORD-777"};
    CMRenderedNotification *result = [self.renderer renderTemplateForKey:@"assigned"
                                                                payload:payload
                                                       tenantConfigJSON:tenantConfig];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.title, @"Order ORD-777 assigned",
        @"Title should be inherited from the bundled template when not overridden");
    XCTAssertEqualObjects(result.body, @"Overridden body only for ORD-777.",
        @"Body should use the tenant override");
}

@end
