//
//  CMNotificationTemplateRenderer.h
//  CourierMatch
//
//  Loads notification templates from Resources/Templates.plist with per-tenant
//  overrides from Tenant.configJSON. Resolves {variable} placeholders from
//  payloadJSON; missing variables render as "[n/a]".
//  See design.md §6.1, questions.md Q6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Result of rendering a template for a given key + payload.
@interface CMRenderedNotification : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *body;
- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface CMNotificationTemplateRenderer : NSObject

/// Shared renderer. Loads the bundled plist on first access.
+ (instancetype)shared;

/// Renders the template identified by `templateKey` using the given payload.
/// Per-tenant overrides are loaded from the tenant's configJSON if available.
///
/// @param templateKey  One of: assigned, picked_up, delivered, dispute_opened, digest.
/// @param payload      Dictionary whose values replace {variableName} tokens.
/// @param tenantConfigJSON  Optional tenant configJSON for per-tenant template overrides.
///                          Expected structure: configJSON[@"templates"][@"<templateKey>"]
///                          with @"title" / @"body" keys.
/// @return A rendered title + body pair. Returns nil only if the templateKey is
///         completely unknown (not in plist and not in tenant config).
- (nullable CMRenderedNotification *)renderTemplateForKey:(NSString *)templateKey
                                                  payload:(nullable NSDictionary *)payload
                                         tenantConfigJSON:(nullable NSDictionary *)tenantConfigJSON;

@end

NS_ASSUME_NONNULL_END
