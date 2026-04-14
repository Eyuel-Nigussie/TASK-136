//
//  CMEncryptedValueTransformer.h
//  CourierMatch
//
//  Core Data `NSValueTransformer` that AES-256-GCM-encrypts NSString/NSData
//  values using a per-install key stored in the Keychain
//  (CMKeychainKey_FieldKey). Flagged attributes declare this transformer.
//  See design.md §3.3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSValueTransformerName const CMEncryptedValueTransformerName;

@interface CMEncryptedValueTransformer : NSValueTransformer

/// Must be called once on app launch before the Core Data stack is loaded.
+ (void)registerTransformer;

@end

NS_ASSUME_NONNULL_END
