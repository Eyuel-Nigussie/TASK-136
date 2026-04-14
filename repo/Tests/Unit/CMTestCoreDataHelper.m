//
//  CMTestCoreDataHelper.m
//  CourierMatch Tests
//

#import "CMTestCoreDataHelper.h"
#import "CMItinerary.h"
#import "CMOrder.h"
#import "CMMatchCandidate.h"
#import "CMTenant.h"
#import "CMRubricTemplate.h"
#import "CMDeliveryScorecard.h"
#import "CMAttachment.h"
#import "CMAuditEntry.h"
#import "CMAddress.h"

@implementation CMTestCoreDataHelper

+ (NSManagedObjectContext *)inMemoryContext {
    // Load the CourierMatch managed object model from the compiled .momd in the test bundle.
    // Fall back to searching all bundles if needed.
    NSManagedObjectModel *model = nil;

    for (NSBundle *bundle in @[[NSBundle mainBundle],
                                [NSBundle bundleForClass:[self class]]]) {
        NSURL *modelURL = [bundle URLForResource:@"CourierMatch"
                                   withExtension:@"momd"];
        if (modelURL) {
            model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
            break;
        }
    }

    if (!model) {
        // Build the model programmatically from known entities as a fallback.
        model = [self buildProgrammaticModel];
    }

    NSPersistentStoreDescription *desc = [[NSPersistentStoreDescription alloc] init];
    desc.type = NSInMemoryStoreType;

    NSPersistentContainer *container =
        [[NSPersistentContainer alloc] initWithName:@"CourierMatch"
                               managedObjectModel:model];
    container.persistentStoreDescriptions = @[desc];

    __block NSError *loadError = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDesc,
                                                            NSError *error) {
        loadError = error;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    NSAssert(loadError == nil, @"Failed to load in-memory store: %@", loadError);

    return container.viewContext;
}

#pragma mark - Programmatic Model Fallback

+ (NSManagedObjectModel *)buildProgrammaticModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSEntityDescription *tenant       = [self tenantEntity];
    NSEntityDescription *order        = [self orderEntity];
    NSEntityDescription *itinerary    = [self itineraryEntity];
    NSEntityDescription *candidate    = [self matchCandidateEntity];
    NSEntityDescription *rubric       = [self rubricTemplateEntity];
    NSEntityDescription *scorecard    = [self deliveryScorecardEntity];
    NSEntityDescription *attachment   = [self attachmentEntity];
    NSEntityDescription *auditEntry   = [self auditEntryEntity];
    NSEntityDescription *notification = [self notificationItemEntity];

    model.entities = @[tenant, order, itinerary, candidate, rubric, scorecard,
                       attachment, auditEntry, notification];
    return model;
}

+ (NSEntityDescription *)tenantEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"Tenant";
    e.managedObjectClassName = @"CMTenant";
    e.properties = @[
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"name"],
        [self stringAttrDefault:@"status" defaultValue:@"active"],
        [self transformableAttr:@"configJSON"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)orderEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"Order";
    e.managedObjectClassName = @"CMOrder";
    e.properties = @[
        [self stringAttr:@"orderId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"externalOrderRef"],
        [self transformableAttr:@"pickupAddress"],
        [self transformableAttr:@"dropoffAddress"],
        [self optionalDateAttr:@"pickupWindowStart"],
        [self optionalDateAttr:@"pickupWindowEnd"],
        [self optionalDateAttr:@"dropoffWindowStart"],
        [self optionalDateAttr:@"dropoffWindowEnd"],
        [self optionalStringAttr:@"pickupTimeZoneIdentifier"],
        [self optionalStringAttr:@"dropoffTimeZoneIdentifier"],
        [self doubleAttr:@"parcelVolumeL"],
        [self doubleAttr:@"parcelWeightKg"],
        [self optionalStringAttr:@"requiresVehicleType"],
        [self stringAttrDefault:@"status" defaultValue:@"new"],
        [self optionalStringAttr:@"assignedCourierId"],
        [self optionalStringAttr:@"customerNotes"],
        [self optionalBinaryAttr:@"sensitiveCustomerId"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)itineraryEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"Itinerary";
    e.managedObjectClassName = @"CMItinerary";
    e.properties = @[
        [self stringAttr:@"itineraryId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"courierId"],
        [self transformableAttr:@"originAddress"],
        [self transformableAttr:@"destinationAddress"],
        [self optionalDateAttr:@"departureWindowStart"],
        [self optionalDateAttr:@"departureWindowEnd"],
        [self stringAttrDefault:@"vehicleType" defaultValue:@"car"],
        [self doubleAttr:@"vehicleCapacityVolumeL"],
        [self doubleAttr:@"vehicleCapacityWeightKg"],
        [self transformableAttr:@"onTheWayStops"],
        [self stringAttrDefault:@"status" defaultValue:@"draft"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)matchCandidateEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"MatchCandidate";
    e.managedObjectClassName = @"CMMatchCandidate";
    e.properties = @[
        [self stringAttr:@"candidateId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"itineraryId"],
        [self stringAttr:@"orderId"],
        [self doubleAttr:@"score"],
        [self doubleAttr:@"detourMiles"],
        [self doubleAttr:@"timeOverlapMinutes"],
        [self doubleAttr:@"capacityRisk"],
        [self transformableAttr:@"explanationComponents"],
        [self int32Attr:@"rankPosition"],
        [self optionalDateAttr:@"computedAt"],
        [self boolAttr:@"stale"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)rubricTemplateEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"RubricTemplate";
    e.managedObjectClassName = @"CMRubricTemplate";
    e.properties = @[
        [self stringAttr:@"rubricId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"name"],
        [self boolAttr:@"active"],
        [self int64AttrDefault:@"rubricVersion" defaultValue:1],
        [self transformableAttr:@"items"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)deliveryScorecardEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"DeliveryScorecard";
    e.managedObjectClassName = @"CMDeliveryScorecard";
    e.properties = @[
        [self stringAttr:@"scorecardId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"orderId"],
        [self stringAttr:@"courierId"],
        [self stringAttr:@"rubricId"],
        [self int64AttrDefault:@"rubricVersion" defaultValue:1],
        [self optionalStringAttr:@"supersedesScorecardId"],
        [self transformableAttr:@"automatedResults"],
        [self transformableAttr:@"manualResults"],
        [self doubleAttr:@"totalPoints"],
        [self doubleAttr:@"maxPoints"],
        [self optionalDateAttr:@"finalizedAt"],
        [self optionalStringAttr:@"finalizedBy"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)attachmentEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"Attachment";
    e.managedObjectClassName = @"CMAttachment";
    e.properties = @[
        [self stringAttr:@"attachmentId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"ownerType"],
        [self stringAttr:@"ownerId"],
        [self stringAttr:@"filename"],
        [self stringAttr:@"mimeType"],
        [self int64AttrDefault:@"sizeBytes" defaultValue:0],
        [self optionalStringAttr:@"sha256Hex"],
        [self dateAttr:@"capturedAt"],
        [self dateAttr:@"expiresAt"],
        [self stringAttr:@"storagePathRelative"],
        [self stringAttr:@"capturedByUserId"],
        [self stringAttrDefault:@"hashStatus" defaultValue:@"pending"],
        [self dateAttr:@"createdAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

+ (NSEntityDescription *)auditEntryEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"AuditEntry";
    e.managedObjectClassName = @"CMAuditEntry";
    e.properties = @[
        [self stringAttr:@"entryId"],
        [self stringAttr:@"tenantId"],
        [self stringAttr:@"actorUserId"],
        [self stringAttr:@"actorRole"],
        [self stringAttr:@"action"],
        [self optionalStringAttr:@"targetType"],
        [self optionalStringAttr:@"targetId"],
        [self transformableAttr:@"beforeJSON"],
        [self transformableAttr:@"afterJSON"],
        [self optionalStringAttr:@"reason"],
        [self dateAttr:@"createdAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalBinaryAttr:@"prevHash"],
        [self optionalBinaryAttr:@"entryHash"],
    ];
    return e;
}

+ (NSEntityDescription *)notificationItemEntity {
    NSEntityDescription *e = [[NSEntityDescription alloc] init];
    e.name = @"NotificationItem";
    e.managedObjectClassName = @"CMNotificationItem";
    e.properties = @[
        [self stringAttr:@"notificationId"],
        [self stringAttr:@"tenantId"],
        [self optionalStringAttr:@"subjectEntityType"],
        [self optionalStringAttr:@"subjectEntityId"],
        [self stringAttr:@"templateKey"],
        [self transformableAttr:@"payloadJSON"],
        [self optionalStringAttr:@"renderedTitle"],
        [self optionalStringAttr:@"renderedBody"],
        [self stringAttr:@"recipientUserId"],
        [self stringAttrDefault:@"status" defaultValue:@"active"],
        [self transformableAttr:@"childIds"],
        [self optionalStringAttr:@"rateLimitBucket"],
        [self dateAttr:@"createdAt"],
        [self optionalDateAttr:@"readAt"],
        [self optionalDateAttr:@"ackedAt"],
        [self dateAttr:@"updatedAt"],
        [self optionalDateAttr:@"deletedAt"],
        [self optionalStringAttr:@"createdBy"],
        [self optionalStringAttr:@"updatedBy"],
        [self int64AttrDefault:@"version" defaultValue:1],
    ];
    return e;
}

#pragma mark - Attribute Builders

+ (NSAttributeDescription *)stringAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSStringAttributeType;
    a.optional = NO;
    return a;
}

+ (NSAttributeDescription *)stringAttrDefault:(NSString *)name defaultValue:(NSString *)dv {
    NSAttributeDescription *a = [self stringAttr:name];
    a.defaultValue = dv;
    return a;
}

+ (NSAttributeDescription *)optionalStringAttr:(NSString *)name {
    NSAttributeDescription *a = [self stringAttr:name];
    a.optional = YES;
    return a;
}

+ (NSAttributeDescription *)dateAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSDateAttributeType;
    a.optional = NO;
    return a;
}

+ (NSAttributeDescription *)optionalDateAttr:(NSString *)name {
    NSAttributeDescription *a = [self dateAttr:name];
    a.optional = YES;
    return a;
}

+ (NSAttributeDescription *)doubleAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSDoubleAttributeType;
    a.defaultValue = @(0.0);
    return a;
}

+ (NSAttributeDescription *)int64AttrDefault:(NSString *)name defaultValue:(int64_t)dv {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSInteger64AttributeType;
    a.defaultValue = @(dv);
    return a;
}

+ (NSAttributeDescription *)int32Attr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSInteger32AttributeType;
    a.defaultValue = @(0);
    return a;
}

+ (NSAttributeDescription *)boolAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSBooleanAttributeType;
    a.defaultValue = @(NO);
    return a;
}

+ (NSAttributeDescription *)transformableAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSTransformableAttributeType;
    a.optional = YES;
    return a;
}

+ (NSAttributeDescription *)optionalBinaryAttr:(NSString *)name {
    NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
    a.name = name;
    a.attributeType = NSBinaryDataAttributeType;
    a.optional = YES;
    return a;
}

#pragma mark - Entity Inserters

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
                     vehicleCapWeightKg:(double)weightKg {
    CMItinerary *it = [NSEntityDescription insertNewObjectForEntityForName:@"Itinerary"
                                                    inManagedObjectContext:ctx];
    it.itineraryId = itineraryId;
    it.tenantId = tenantId;
    it.courierId = courierId;
    it.originAddress = origin;
    it.destinationAddress = dest;
    it.departureWindowStart = depStart;
    it.departureWindowEnd = depEnd;
    it.vehicleType = vehicleType;
    it.vehicleCapacityVolumeL = volumeL;
    it.vehicleCapacityWeightKg = weightKg;
    it.status = CMItineraryStatusActive;
    it.createdAt = [NSDate date];
    it.updatedAt = [NSDate date];
    return it;
}

+ (CMOrder *)insertOrderInContext:(NSManagedObjectContext *)ctx
                          orderId:(NSString *)orderId
                         tenantId:(NSString *)tenantId
                    pickupAddress:(CMAddress *)pickup
                   dropoffAddress:(CMAddress *)dropoff
                pickupWindowStart:(NSDate *)pwStart
                  pickupWindowEnd:(NSDate *)pwEnd
               dropoffWindowStart:(NSDate *)dwStart
                 dropoffWindowEnd:(NSDate *)dwEnd
                     parcelVolume:(double)volumeL
                     parcelWeight:(double)weightKg
              requiresVehicleType:(NSString *)reqVehicle
                           status:(NSString *)status {
    CMOrder *o = [NSEntityDescription insertNewObjectForEntityForName:@"Order"
                                              inManagedObjectContext:ctx];
    o.orderId = orderId;
    o.tenantId = tenantId;
    o.externalOrderRef = orderId;
    o.pickupAddress = pickup;
    o.dropoffAddress = dropoff;
    o.pickupWindowStart = pwStart;
    o.pickupWindowEnd = pwEnd;
    o.dropoffWindowStart = dwStart;
    o.dropoffWindowEnd = dwEnd;
    o.parcelVolumeL = volumeL;
    o.parcelWeightKg = weightKg;
    o.requiresVehicleType = reqVehicle;
    o.status = status;
    o.createdAt = [NSDate date];
    o.updatedAt = [NSDate date];
    return o;
}

+ (CMMatchCandidate *)insertCandidateInContext:(NSManagedObjectContext *)ctx
                                   candidateId:(NSString *)candidateId
                                   itineraryId:(NSString *)itineraryId
                                       orderId:(NSString *)orderId
                                         score:(double)score
                                   detourMiles:(double)detourMiles
                            timeOverlapMinutes:(double)timeOverlapMinutes
                                  capacityRisk:(double)capacityRisk
                                  rankPosition:(int32_t)rank {
    CMMatchCandidate *c = [NSEntityDescription insertNewObjectForEntityForName:@"MatchCandidate"
                                                        inManagedObjectContext:ctx];
    c.candidateId = candidateId;
    c.tenantId = @"test-tenant";
    c.itineraryId = itineraryId;
    c.orderId = orderId;
    c.score = score;
    c.detourMiles = detourMiles;
    c.timeOverlapMinutes = timeOverlapMinutes;
    c.capacityRisk = capacityRisk;
    c.rankPosition = rank;
    c.computedAt = [NSDate date];
    c.stale = NO;
    c.createdAt = [NSDate date];
    c.updatedAt = [NSDate date];
    return c;
}

+ (CMTenant *)insertTenantInContext:(NSManagedObjectContext *)ctx
                           tenantId:(NSString *)tenantId
                               name:(NSString *)name
                         configJSON:(NSDictionary *)configJSON {
    CMTenant *t = [NSEntityDescription insertNewObjectForEntityForName:@"Tenant"
                                               inManagedObjectContext:ctx];
    t.tenantId = tenantId;
    t.name = name;
    t.status = @"active";
    t.configJSON = configJSON;
    t.createdAt = [NSDate date];
    t.updatedAt = [NSDate date];
    return t;
}

+ (CMRubricTemplate *)insertRubricInContext:(NSManagedObjectContext *)ctx
                                   rubricId:(NSString *)rubricId
                                   tenantId:(NSString *)tenantId
                                       name:(NSString *)name
                                     active:(BOOL)active
                              rubricVersion:(int64_t)version
                                      items:(NSArray *)items {
    CMRubricTemplate *r = [NSEntityDescription insertNewObjectForEntityForName:@"RubricTemplate"
                                                       inManagedObjectContext:ctx];
    r.rubricId = rubricId;
    r.tenantId = tenantId;
    r.name = name;
    r.active = active;
    r.rubricVersion = version;
    r.items = items;
    r.createdAt = [NSDate date];
    r.updatedAt = [NSDate date];
    return r;
}

+ (CMDeliveryScorecard *)insertScorecardInContext:(NSManagedObjectContext *)ctx
                                      scorecardId:(NSString *)scorecardId
                                          orderId:(NSString *)orderId
                                        courierId:(NSString *)courierId
                                         rubricId:(NSString *)rubricId
                                    rubricVersion:(int64_t)version {
    CMDeliveryScorecard *s = [NSEntityDescription insertNewObjectForEntityForName:@"DeliveryScorecard"
                                                          inManagedObjectContext:ctx];
    s.scorecardId = scorecardId;
    s.tenantId = @"test-tenant";
    s.orderId = orderId;
    s.courierId = courierId;
    s.rubricId = rubricId;
    s.rubricVersion = version;
    s.automatedResults = @[];
    s.manualResults = @[];
    s.createdAt = [NSDate date];
    s.updatedAt = [NSDate date];
    return s;
}

+ (CMAttachment *)insertAttachmentInContext:(NSManagedObjectContext *)ctx
                              attachmentId:(NSString *)attachmentId
                                  tenantId:(NSString *)tenantId
                                 ownerType:(NSString *)ownerType
                                   ownerId:(NSString *)ownerId
                                  filename:(NSString *)filename
                                  mimeType:(NSString *)mimeType
                                 sizeBytes:(int64_t)sizeBytes {
    CMAttachment *a = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment"
                                                   inManagedObjectContext:ctx];
    a.attachmentId = attachmentId;
    a.tenantId = tenantId;
    a.ownerType = ownerType;
    a.ownerId = ownerId;
    a.filename = filename;
    a.mimeType = mimeType;
    a.sizeBytes = sizeBytes;
    a.capturedAt = [NSDate date];
    a.expiresAt = [[NSDate date] dateByAddingTimeInterval:86400];
    a.storagePathRelative = [NSString stringWithFormat:@"attachments/%@", attachmentId];
    a.capturedByUserId = @"test-user";
    a.hashStatus = @"pending";
    a.createdAt = [NSDate date];
    a.updatedAt = [NSDate date];
    return a;
}

+ (CMAuditEntry *)insertAuditEntryInContext:(NSManagedObjectContext *)ctx
                                    entryId:(NSString *)entryId
                                   tenantId:(NSString *)tenantId
                                actorUserId:(NSString *)actorUserId
                                  actorRole:(NSString *)actorRole
                                     action:(NSString *)action
                                  createdAt:(NSDate *)createdAt {
    CMAuditEntry *e = [NSEntityDescription insertNewObjectForEntityForName:@"AuditEntry"
                                                    inManagedObjectContext:ctx];
    e.entryId = entryId;
    e.tenantId = tenantId;
    e.actorUserId = actorUserId;
    e.actorRole = actorRole;
    e.action = action;
    e.createdAt = createdAt;
    return e;
}

+ (CMAddress *)addressWithLat:(double)lat lng:(double)lng zip:(NSString *)zip {
    CMAddress *addr = [[CMAddress alloc] init];
    addr.lat = lat;
    addr.lng = lng;
    addr.zip = zip;
    return addr;
}

@end
