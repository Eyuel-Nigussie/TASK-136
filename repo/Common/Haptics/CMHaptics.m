//
//  CMHaptics.m
//  CourierMatch
//

#import "CMHaptics.h"

@implementation CMHaptics

+ (void)success {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen prepare];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
}

+ (void)error {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen prepare];
    [gen notificationOccurred:UINotificationFeedbackTypeError];
}

+ (void)warning {
    UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen prepare];
    [gen notificationOccurred:UINotificationFeedbackTypeWarning];
}

+ (void)selectionChanged {
    UISelectionFeedbackGenerator *gen = [[UISelectionFeedbackGenerator alloc] init];
    [gen prepare];
    [gen selectionChanged];
}

@end
