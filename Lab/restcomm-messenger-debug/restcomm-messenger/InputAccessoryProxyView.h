#import <UIKit/UIKit.h>
#import "ViewController.h"
#import "MessageViewController.h"

@interface InputAccessoryProxyView : UIView
- (id)initWithFrame:(CGRect)rect viewController:(MessageViewController *)viewController;
// we don't own it
@property (weak, nonatomic) MessageViewController * viewController;
@end
