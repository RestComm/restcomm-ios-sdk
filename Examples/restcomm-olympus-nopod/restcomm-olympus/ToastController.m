//
//  ToastController.m
//  restcomm-olympus
//
//  Created by Antonis Tsakiridis on 4/26/16.
//  Copyright © 2016 TeleStax. All rights reserved.
//

#import "ToastController.h"

@interface ToastController ()
// is there a toast currently active
@property BOOL toastActive;
@property NSMutableArray * toastQueue;
@end

@implementation ToastController

+ (id)sharedInstance {
    static ToastController *sharedToastController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedToastController = [[self alloc] init];
    });
    return sharedToastController;
}

- (id)init {
    if (self = [super init]) {
        _toastActive = NO;
        _toastQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

- (void)showToastWithText:(NSString*)text withDuration:(float)duration
{
    if (_toastActive) {
        // there's already a toast active. Add new tost in the queuea and return
        [_toastQueue addObject:@{ @"text" : text, @"duration" : @(duration) }];
        return;
    }
    
    // get a reference of the root Window. We use the root instead of the current so that it works propery through views transitions
    UIView * rootView = [[UIApplication sharedApplication] keyWindow];
    
    UIView *toastView = [[UIView alloc] initWithFrame:rootView.bounds];
    [toastView.layer setCornerRadius:15.0f];
    [toastView setBackgroundColor:[UIColor colorWithRed:37.0/255.0 green:37.0/255.0 blue:37.0/255.0 alpha:255.0/255.0]];
    toastView.layer.shadowColor = [UIColor blackColor].CGColor;
    toastView.layer.shadowOffset = CGSizeMake(-2, 3);
    toastView.layer.shadowOpacity = 0.7;
    toastView.layer.shadowRadius = 3.0;
    toastView.alpha = 0.7;
    // need that to enable Auto Layout (which is disabled by default for view created programmatically)
    toastView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *label = [[UILabel alloc] initWithFrame:rootView.bounds];
    [label setTextColor:[UIColor colorWithRed:230.0/255.0 green:230.0/255.0 blue:230.0/255.0 alpha:255.0/255.0]];
    // wrap if needed
    label.numberOfLines = 0;
    [label setFont:[UIFont fontWithName: @"System" size: 10.0f]];
    [label setText:text];
    label.textAlignment = NSTextAlignmentCenter;
    // need that to enable Auto Layout (which is disabled by default for view created programmatically)
    label.translatesAutoresizingMaskIntoConstraints = NO;
    
    // need to add views into hieararchy before adding any Auto Layout constraints
    [rootView addSubview:toastView];
    [toastView addSubview:label];
    
    
    // remember that when adding an Auto Layout constraint the addConstraint should be called in the superview
    // center toastView within parent view
    [rootView addConstraint:[NSLayoutConstraint constraintWithItem:toastView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:rootView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:0.0f]];
    [rootView addConstraint:[NSLayoutConstraint constraintWithItem:toastView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:rootView attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f]];
    
    // don't allow toastView to grow more than 90% of parent view in sized and 50% in width
    float maxWidth = [[UIScreen mainScreen] bounds].size.width * 0.8;
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:toastView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0.0f constant:maxWidth]];
    float maxHeight = [[UIScreen mainScreen] bounds].size.height * 0.5;
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:toastView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:0.0f constant:maxHeight]];
    
    // add constant margins between label and toast view (for some strange reason adding a constant bigger than 0.0f messes this up)
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:toastView attribute:NSLayoutAttributeTopMargin multiplier:1.0f constant:0.0f]];
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:toastView attribute:NSLayoutAttributeLeadingMargin multiplier:1.0f constant:0.0f]];
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:toastView attribute:NSLayoutAttributeBottomMargin multiplier:1.0f constant:0.0f]];
    [toastView addConstraint:[NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:toastView attribute:NSLayoutAttributeTrailingMargin multiplier:1.0f constant:0.0f]];
    
    _toastActive = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.4
                         animations:^(void) {
                             toastView.alpha = 0;
                         }
                         completion:^(BOOL finished){
                             [UIView animateWithDuration:1.0 animations:^(void) {
                                 [toastView removeFromSuperview];
                             }];
                             
                             _toastActive = NO;
                             // check if there are pending toasts in the queue
                             if ([_toastQueue count] > 0) {
                                 NSDictionary * upcomingToast = [_toastQueue objectAtIndex:0];
                                 [self showToastWithText:[upcomingToast objectForKey:@"text"]
                                            withDuration:[[upcomingToast objectForKey:@"duration"] floatValue]];
                                 [_toastQueue removeObjectAtIndex:0];
                             }
                         }];
    });
}

@end
