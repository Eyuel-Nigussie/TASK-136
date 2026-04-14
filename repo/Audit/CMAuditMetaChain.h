//
//  CMAuditMetaChain.h
//  CourierMatch
//
//  Device-wide meta-chain that records (tenantId, newHead, actorUserId, timestamp)
//  every time a tenant's audit chain head changes.
//  Uses its own hash chain with the non-deletable meta seed.
//  See design.md §10.3 and questions.md Q8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A single immutable entry in the device-wide meta-chain.
/// Stored as an NSDictionary serialized to a plist on disk.
@interface CMAuditMetaEntry : NSObject <NSSecureCoding>
@property (nonatomic, copy, readonly)             NSString *tenantId;
@property (nonatomic, copy, readonly, getter=chainNewHead) NSData *newHead;
@property (nonatomic, copy, readonly)             NSString *actorUserId;
@property (nonatomic, copy, readonly)             NSDate   *timestamp;
@property (nonatomic, copy, readonly, nullable)   NSData   *prevHash;
@property (nonatomic, copy, readonly)             NSData   *entryHash;

- (instancetype)initWithTenantId:(NSString *)tenantId
                         newHead:(NSData *)newHead
                     actorUserId:(NSString *)actorUserId
                       timestamp:(NSDate *)timestamp
                        prevHash:(nullable NSData *)prevHash
                       entryHash:(NSData *)entryHash;
- (instancetype)init NS_UNAVAILABLE;
@end


@interface CMAuditMetaChain : NSObject

/// Shared singleton. The meta-chain state lives in a plist file under
/// the Application Support directory. Thread-safe via serial queue.
+ (instancetype)shared;

/// Appends an entry to the meta-chain recording a tenant chain head change.
/// @param tenantId    The tenant whose chain head changed.
/// @param newHead     The entryHash of the new chain head.
/// @param actorUserId The user who triggered the change.
/// @param error       Set on failure.
/// @return YES on success.
- (BOOL)recordHeadChangeForTenant:(NSString *)tenantId
                          newHead:(NSData *)newHead
                      actorUserId:(NSString *)actorUserId
                            error:(NSError **)error;

/// Returns all meta-chain entries in chronological order.
- (NSArray<CMAuditMetaEntry *> *)allEntries;

/// Verifies the meta-chain integrity. Returns YES if valid.
/// On broken chain: sets error with CMErrorCodeAuditChainBroken.
- (BOOL)verifyChain:(NSError **)error;

/// Returns the most recent meta-chain entry for the given tenant, or nil.
- (nullable CMAuditMetaEntry *)latestEntryForTenant:(NSString *)tenantId;

@end

NS_ASSUME_NONNULL_END
