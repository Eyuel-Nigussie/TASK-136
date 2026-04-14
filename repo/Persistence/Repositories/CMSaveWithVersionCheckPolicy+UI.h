//
//  CMSaveWithVersionCheckPolicy+UI.h
//  CourierMatch
//
//  Convenience wrapper that integrates CMSaveWithVersionCheckPolicy with a
//  UIAlertController-based conflict resolver. Presents "Keep Mine" / "Keep Theirs"
//  choices per conflicting field when optimistic locking detects a version mismatch.
//

#import "CMSaveWithVersionCheckPolicy.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMSaveWithVersionCheckPolicy (UI)

/// Saves `changes` through the version-check policy and, on field conflicts,
/// presents a UIAlertController from `viewController` with per-field
/// "Keep Mine" / "Keep Theirs" choices.
///
/// @param changes         Attribute name -> new value.
/// @param object          The managed object to save.
/// @param baseVersion     The version the caller loaded before editing.
/// @param viewController  The VC to present the conflict alert from.
/// @param completion      Called with YES if save succeeded (possibly after resolution),
///                        NO if the user cancelled or save failed.
+ (void)saveChanges:(NSDictionary<NSString *, id> *)changes
           toObject:(NSManagedObject *)object
        baseVersion:(int64_t)baseVersion
fromViewController:(UIViewController *)viewController
         completion:(nullable void (^)(BOOL saved))completion;

@end

NS_ASSUME_NONNULL_END
