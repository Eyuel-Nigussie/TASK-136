//
//  CMNotificationTemplateRenderer.m
//  CourierMatch
//

#import "CMNotificationTemplateRenderer.h"
#import "CMDebugLogger.h"

static NSString * const kTag = @"notif.renderer";

#pragma mark - CMRenderedNotification

@implementation CMRenderedNotification

- (instancetype)initWithTitle:(NSString *)title body:(NSString *)body {
    if ((self = [super init])) {
        _title = [title copy];
        _body  = [body copy];
    }
    return self;
}

@end

#pragma mark - CMNotificationTemplateRenderer

@interface CMNotificationTemplateRenderer ()
/// Bundled templates keyed by templateKey -> { title, body }.
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *bundledTemplates;
@end

@implementation CMNotificationTemplateRenderer

+ (instancetype)shared {
    static CMNotificationTemplateRenderer *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[CMNotificationTemplateRenderer alloc] init]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _bundledTemplates = [self loadBundledTemplates];
    }
    return self;
}

#pragma mark - Template loading

- (NSDictionary<NSString *, NSDictionary *> *)loadBundledTemplates {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Templates" ofType:@"plist"];
    if (!path) {
        CMLogWarn(kTag, @"Templates.plist not found in main bundle");
        return @{};
    }
    NSDictionary *loaded = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!loaded) {
        CMLogWarn(kTag, @"Templates.plist could not be parsed");
        return @{};
    }
    CMLogInfo(kTag, @"loaded %lu bundled templates", (unsigned long)loaded.count);
    return loaded;
}

#pragma mark - Public API

- (CMRenderedNotification *)renderTemplateForKey:(NSString *)templateKey
                                         payload:(NSDictionary *)payload
                                tenantConfigJSON:(NSDictionary *)tenantConfigJSON {
    // 1. Resolve the template source: tenant override wins, then bundled.
    NSDictionary *templateDict = [self resolveTemplateForKey:templateKey
                                            tenantConfigJSON:tenantConfigJSON];
    if (!templateDict) {
        CMLogWarn(kTag, @"no template found for key '%@'", templateKey);
        return nil;
    }

    NSString *titleTemplate = templateDict[@"title"] ?: @"";
    NSString *bodyTemplate  = templateDict[@"body"]  ?: @"";

    // 2. Resolve placeholders.
    NSString *renderedTitle = [self resolveTemplate:titleTemplate withPayload:payload];
    NSString *renderedBody  = [self resolveTemplate:bodyTemplate  withPayload:payload];

    CMLogInfo(kTag, @"rendered template '%@' -> title=%lu chars, body=%lu chars",
              templateKey, (unsigned long)renderedTitle.length, (unsigned long)renderedBody.length);

    return [[CMRenderedNotification alloc] initWithTitle:renderedTitle body:renderedBody];
}

#pragma mark - Private

/// Returns the best-matching template dictionary for a given key.
/// Tenant config overrides (configJSON[@"templates"][@"<key>"]) take priority.
- (NSDictionary *)resolveTemplateForKey:(NSString *)templateKey
                       tenantConfigJSON:(NSDictionary *)tenantConfigJSON {
    // Check tenant-level override first.
    if ([tenantConfigJSON isKindOfClass:[NSDictionary class]]) {
        NSDictionary *tenantTemplates = tenantConfigJSON[@"templates"];
        if ([tenantTemplates isKindOfClass:[NSDictionary class]]) {
            NSDictionary *override = tenantTemplates[templateKey];
            if ([override isKindOfClass:[NSDictionary class]] &&
                (override[@"title"] || override[@"body"])) {
                CMLogInfo(kTag, @"using tenant override for template '%@'", templateKey);
                // Merge: tenant values win, fall back to bundled for missing keys.
                NSDictionary *bundled = self.bundledTemplates[templateKey];
                NSMutableDictionary *merged = [NSMutableDictionary dictionary];
                if (bundled[@"title"]) merged[@"title"] = bundled[@"title"];
                if (bundled[@"body"])  merged[@"body"]  = bundled[@"body"];
                if (override[@"title"]) merged[@"title"] = override[@"title"];
                if (override[@"body"])  merged[@"body"]  = override[@"body"];
                return [merged copy];
            }
        }
    }

    // Fall back to bundled plist.
    return self.bundledTemplates[templateKey];
}

/// Deterministic resolver: replaces every `{variableName}` token in the
/// template string with the corresponding value from the payload dictionary.
/// Missing variables are replaced with `[n/a]`.
- (NSString *)resolveTemplate:(NSString *)templateStr withPayload:(NSDictionary *)payload {
    if (templateStr.length == 0) return @"";

    NSMutableString *result = [templateStr mutableCopy];
    // Regex matches {alphanumeric_underscore} tokens.
    NSRegularExpression *regex =
        [NSRegularExpression regularExpressionWithPattern:@"\\{([A-Za-z0-9_]+)\\}"
                                                 options:0
                                                   error:NULL];
    // Walk matches in reverse so replacement doesn't shift indices.
    NSArray<NSTextCheckingResult *> *matches =
        [regex matchesInString:result options:0 range:NSMakeRange(0, result.length)];

    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSRange fullRange = [match rangeAtIndex:0];
        NSRange nameRange = [match rangeAtIndex:1];
        NSString *variableName = [result substringWithRange:nameRange];

        id value = payload[variableName];
        NSString *replacement;
        if (value) {
            replacement = [NSString stringWithFormat:@"%@", value];
        } else {
            replacement = @"[n/a]";
        }
        [result replaceCharactersInRange:fullRange withString:replacement];
    }

    return [result copy];
}

@end
