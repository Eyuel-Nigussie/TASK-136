//
//  CMItineraryFormViewController.h
//  CourierMatch
//
//  Reusable form for creating and editing itineraries. Fields: origin address,
//  destination address, departure window start/end, vehicle type, capacity
//  (volume L, weight kg), and on-the-way stops.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CMItinerary;

@interface CMItineraryFormViewController : UIViewController

/// Create mode: pass nil for itinerary.
/// Edit mode: pass existing itinerary to pre-populate.
- (instancetype)initWithItinerary:(nullable CMItinerary *)itinerary;

@end

NS_ASSUME_NONNULL_END
