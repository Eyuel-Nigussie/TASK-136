//
//  CMItineraryDetailViewController.h
//  CourierMatch
//
//  Displays itinerary details: origin/dest addresses, time window, vehicle,
//  on-the-way stops list. Edit button pushes edit form.
//

#import <UIKit/UIKit.h>

@class CMItinerary;

NS_ASSUME_NONNULL_BEGIN

@interface CMItineraryDetailViewController : UIViewController

- (instancetype)initWithItinerary:(CMItinerary *)itinerary;

@end

NS_ASSUME_NONNULL_END
