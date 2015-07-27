//
//  NavigationController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 7/27/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RestCommClient.h"

@interface SettingsNavigationController : UINavigationController
// owner is ViewController
@property (weak) RCDevice * device;
@end
