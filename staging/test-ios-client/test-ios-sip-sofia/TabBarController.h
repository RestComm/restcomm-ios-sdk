//
//  TabBarController.h
//  test-ios-client
//
//  Created by Antonis Tsakiridis on 10/11/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RestCommClient.h"

@interface TabBarController : UITabBarController
// owner of RCDevice is ViewControllelr
@property (weak) RCDevice* device;
@end
