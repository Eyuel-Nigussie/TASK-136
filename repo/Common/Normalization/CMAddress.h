//
//  CMAddress.h
//  CourierMatch
//
//  Embeddable address value type. Stored as a Transformable in Core Data
//  entities (Itinerary, Order) via CMAddressTransformer.
//  See design.md §3.1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMAddress : NSObject <NSSecureCoding, NSCopying>

@property (nonatomic, copy, nullable) NSString *line1;
@property (nonatomic, copy, nullable) NSString *line2;
@property (nonatomic, copy, nullable) NSString *city;
@property (nonatomic, copy, nullable) NSString *stateAbbr;
@property (nonatomic, copy, nullable) NSString *zip;
@property (nonatomic, assign) double lat;
@property (nonatomic, assign) double lng;
@property (nonatomic, copy, nullable) NSString *normalizedKey;

- (NSDictionary<NSString *, id> *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary<NSString *, id> *)dict;

@end

NS_ASSUME_NONNULL_END
