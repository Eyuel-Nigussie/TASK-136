//
//  CMMatchListViewController.h
//  CourierMatch
//
//  Ranked match candidates for an itinerary. Each cell shows rank #,
//  order ref, score, explanation string, detour + time overlap values.
//  Skeleton loading state during recomputation.
//  Uses CMMatchEngine.rankCandidatesForItinerary:, recomputeCandidatesForItinerary:.
//  Listens for CMMatchEngineDidRecomputeNotification.
//

#import <UIKit/UIKit.h>

@class CMItinerary;

NS_ASSUME_NONNULL_BEGIN

@interface CMMatchListViewController : UIViewController

- (instancetype)initWithItinerary:(CMItinerary *)itinerary;

@end

NS_ASSUME_NONNULL_END
