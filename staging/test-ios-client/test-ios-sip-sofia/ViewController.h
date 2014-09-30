//
//  ViewController.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SipManager.h"

@class SipManager;
@interface ViewController : UIViewController<SipManagerDelegate>
@property SipManager * sipManager;
@end
