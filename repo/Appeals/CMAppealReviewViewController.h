//
//  CMAppealReviewViewController.h
//  CourierMatch
//
//  Shows appeal details: before-score snapshot, proposed after-scores (editable
//  for "adjust" decision). Decision picker (uphold/adjust/reject) + notes.
//  Finance gate shown when monetaryImpact.
//  Submit via CMAppealService.submitDecision.
//  Audit trail display (read-only list of CMAuditEntry records).
//

#import <UIKit/UIKit.h>

@class CMAppeal;

NS_ASSUME_NONNULL_BEGIN

@interface CMAppealReviewViewController : UIViewController

- (instancetype)initWithAppeal:(CMAppeal *)appeal;

@end

NS_ASSUME_NONNULL_END
