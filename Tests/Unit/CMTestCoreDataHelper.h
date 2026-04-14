//
//  CMTestCoreDataHelper.h
//  CourierMatch Tests
//
//  In-memory Core Data stack for unit testing. Loads the CourierMatch model
//  and returns a main-queue context suitable for synchronous test assertions.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CMItinerary;
@class CMOrder;
@class CMMatchCandidate;
@class CMTenant;
@class CMRubricTemplate;
@class CMDeliveryScorecard;
@class CMAttachment;
@class CMAuditEntry;
@class CMAddress;

NS_ASSUME_NONNULL_BEGIN

@interface CMTestCoreDataHelper : NSObject

/// Creates an in-memory NSPersistentContainer loading the CourierMatch model.
/// Returns a main-queue context for synchronous testing.
+ (NSManagedObjectContext *)inMemoryContext;

/// Insert a test Itinerary with controlled field values.
+ (CMItinerary *)insertItineraryInContext:(NSManagedObjectContext *)ctx
                             itineraryId:(NSString *)itineraryId
                                tenantId:(NSString *)tenantId
                               courierId:(NSString *)courierId
                           originAddress:(CMAddress *)origin
                      destinationAddress:(CMAddress *)dest
                    departureWindowStart:(NSDate *)depStart
                      departureWindowEnd:(NSDate *)depEnd
                             vehicleType:(NSString *)vehicleType
                      vehicleCapVolumeL:(double)volumeL
                     vehicleCapWeightKg:(double)weightKg;

/// Insert a test Order with controlled field values.
+ (CMOrder *)insertOrderInContext:(NSManagedObjectContext *)ctx
                          orderId:(NSString *)orderId
                         tenantId:(NSString *)tenantId
                    pickupAddress:(CMAddress *)pickup
                   dropoffAddress:(CMAddress *)dropoff
                pickupWindowStart:(NSDate *)pwStart
                  pickupWindowEnd:(NSDate *)pwEnd
               dropoffWindowStart:(nullable NSDate *)dwStart
                 dropoffWindowEnd:(nullable NSDate *)dwEnd
                     parcelVolume:(double)volumeL
                     parcelWeight:(double)weightKg
              requiresVehicleType:(nullable NSString *)reqVehicle
                           status:(NSString *)status;

/// Insert a test MatchCandidate with controlled field values.
+ (CMMatchCandidate *)insertCandidateInContext:(NSManagedObjectContext *)ctx
                                   candidateId:(NSString *)candidateId
                                   itineraryId:(NSString *)itineraryId
                                       orderId:(NSString *)orderId
                                         score:(double)score
                                   detourMiles:(double)detourMiles
                            timeOverlapMinutes:(double)timeOverlapMinutes
                                  capacityRisk:(double)capacityRisk
                                  rankPosition:(int32_t)rank;

/// Insert a test Tenant.
+ (CMTenant *)insertTenantInContext:(NSManagedObjectContext *)ctx
                           tenantId:(NSString *)tenantId
                               name:(NSString *)name
                         configJSON:(nullable NSDictionary *)configJSON;

/// Insert a test RubricTemplate.
+ (CMRubricTemplate *)insertRubricInContext:(NSManagedObjectContext *)ctx
                                   rubricId:(NSString *)rubricId
                                   tenantId:(NSString *)tenantId
                                       name:(NSString *)name
                                     active:(BOOL)active
                              rubricVersion:(int64_t)version
                                      items:(NSArray *)items;

/// Insert a test DeliveryScorecard.
+ (CMDeliveryScorecard *)insertScorecardInContext:(NSManagedObjectContext *)ctx
                                      scorecardId:(NSString *)scorecardId
                                          orderId:(NSString *)orderId
                                        courierId:(NSString *)courierId
                                         rubricId:(NSString *)rubricId
                                    rubricVersion:(int64_t)version;

/// Insert a test Attachment.
+ (CMAttachment *)insertAttachmentInContext:(NSManagedObjectContext *)ctx
                              attachmentId:(NSString *)attachmentId
                                  tenantId:(NSString *)tenantId
                                 ownerType:(NSString *)ownerType
                                   ownerId:(NSString *)ownerId
                                  filename:(NSString *)filename
                                  mimeType:(NSString *)mimeType
                                 sizeBytes:(int64_t)sizeBytes;

/// Insert a test AuditEntry.
+ (CMAuditEntry *)insertAuditEntryInContext:(NSManagedObjectContext *)ctx
                                    entryId:(NSString *)entryId
                                   tenantId:(NSString *)tenantId
                                actorUserId:(NSString *)actorUserId
                                  actorRole:(NSString *)actorRole
                                     action:(NSString *)action
                                  createdAt:(NSDate *)createdAt;

/// Create a CMAddress with lat/lng and zip.
+ (CMAddress *)addressWithLat:(double)lat lng:(double)lng zip:(nullable NSString *)zip;

@end

NS_ASSUME_NONNULL_END
