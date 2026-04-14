//
//  CMPasswordPolicy.h
//  CourierMatch
//
//  Password validation per design.md §4.1:
//   - Minimum 12 characters
//   - At least 1 digit
//   - At least 1 symbol (from a documented class)
//   - Rejected against embedded common-password blocklist
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, CMPasswordViolation) {
    CMPasswordViolationNone          = 0,
    CMPasswordViolationTooShort      = 1 << 0,
    CMPasswordViolationMissingDigit  = 1 << 1,
    CMPasswordViolationMissingSymbol = 1 << 2,
    CMPasswordViolationBlocklisted   = 1 << 3,
    CMPasswordViolationEmpty         = 1 << 4,
};

@interface CMPasswordPolicy : NSObject

+ (instancetype)shared;

/// Documented symbol class. Anything outside [A-Za-z0-9] counts.
@property (nonatomic, readonly) NSCharacterSet *symbolClass;

/// Configurable minimum length. Defaults to 12.
@property (nonatomic, readonly) NSUInteger minimumLength;

/// Returns `CMPasswordViolationNone` iff the password passes all rules.
- (CMPasswordViolation)evaluate:(NSString *)password;

/// Human-readable summary of violations, e.g. "Needs a digit; Needs a symbol".
- (NSString *)summaryForViolations:(CMPasswordViolation)violations;

@end

NS_ASSUME_NONNULL_END
