//
//  ViewController.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

//#import "SofiaSIP.h"
@class SofiaSIP;
@interface ViewController : UIViewController
- (void)incomingCall;
- (void)incomingMsg:(NSString*)msg;

@property SofiaSIP * sofiaSIP;
@end
