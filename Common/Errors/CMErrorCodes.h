//
//  CMErrorCodes.h
//  CourierMatch
//
//  Unified NSError code space for the `CMErrorDomain`.
//  See design.md §16.
//

#ifndef CMErrorCodes_h
#define CMErrorCodes_h

#import <Foundation/Foundation.h>

extern NSErrorDomain const CMErrorDomain;

typedef NS_ERROR_ENUM(CMErrorDomain, CMErrorCode) {
    CMErrorCodeUnknown                      = 0,

    // 1xxx — persistence
    CMErrorCodeCoreDataBootFailed           = 1001,
    CMErrorCodeCoreDataSaveFailed           = 1002,
    CMErrorCodeOptimisticLockConflict       = 1003,
    CMErrorCodeTenantScopingViolation       = 1004,
    CMErrorCodeUniqueConstraintViolated     = 1005,

    // 2xxx — auth
    CMErrorCodePasswordPolicyViolation      = 2001,
    CMErrorCodeAuthInvalidCredentials       = 2002,
    CMErrorCodeAuthAccountLocked            = 2003,
    CMErrorCodeAuthCaptchaRequired          = 2004,
    CMErrorCodeAuthCaptchaFailed            = 2005,
    CMErrorCodeAuthSessionExpired           = 2006,
    CMErrorCodeAuthForcedLogout             = 2007,
    CMErrorCodeBiometricUnavailable         = 2008,

    // 3xxx — crypto / keychain
    CMErrorCodeKeychainOperationFailed      = 3001,
    CMErrorCodeCryptoOperationFailed        = 3002,
    CMErrorCodeCryptoIntegrityCheckFailed   = 3003,

    // 4xxx — files / attachments
    CMErrorCodeAttachmentTooLarge           = 4001,
    CMErrorCodeAttachmentMimeNotAllowed     = 4002,
    CMErrorCodeAttachmentMagicMismatch      = 4003,
    CMErrorCodeAttachmentHashMismatch       = 4004,
    CMErrorCodeFileIOFailed                 = 4005,

    // 5xxx — domain / validation
    CMErrorCodeValidationFailed             = 5001,
    CMErrorCodeRubricVersionMismatch        = 5002,
    CMErrorCodeScorecardAlreadyFinalized    = 5003,
    CMErrorCodePermissionDenied             = 5004,
    CMErrorCodeMatchCandidateTruncated      = 5005,

    // 6xxx — import / normalization
    CMErrorCodeImportFileTooLarge           = 6001,
    CMErrorCodeImportRowCountExceeded       = 6002,
    CMErrorCodeImportFieldTooLarge          = 6003,
    CMErrorCodeImportSchemaInvalid          = 6004,
    CMErrorCodeAddressInvalid               = 6005,

    // 7xxx — audit
    CMErrorCodeAuditChainBroken             = 7001,
    CMErrorCodeAuditSeedMissing             = 7002,
    CMErrorCodeAuditWriteFailed             = 7003,
};

#endif /* CMErrorCodes_h */
