//
//  CMItineraryListViewController.h
//  CourierMatch
//
//  Courier's active itineraries list. Each row shows origin -> destination,
//  departure window, vehicle type, and status badge.
//  Pull-to-refresh recomputes matches. Shows "Last refreshed at..."
//  Uses CMItineraryRepository.activeForCourierId:.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMItineraryListViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
