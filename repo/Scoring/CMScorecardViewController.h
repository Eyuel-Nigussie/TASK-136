//
//  CMScorecardViewController.h
//  CourierMatch
//
//  Scorecard view: rubric items as rows. Automatic items show points + evidence.
//  Manual items have stepper bounded by maxPoints + notes text field
//  (required when below half). Banner if newer rubric version available.
//  "Finalize" button. Uses CMScoringEngine. Haptic feedback on finalization.
//

#import <UIKit/UIKit.h>

@class CMDeliveryScorecard;

NS_ASSUME_NONNULL_BEGIN

@interface CMScorecardViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

- (instancetype)initWithScorecard:(CMDeliveryScorecard *)scorecard;

@end

NS_ASSUME_NONNULL_END
