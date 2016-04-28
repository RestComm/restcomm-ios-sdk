//
//  ICESettingsNavigationController.h
//  restcomm-olympus
//
//  Created by Antonis Tsakiridis on 2/25/16.
//  Copyright © 2016 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RestCommClient.h"

@interface ICESettingsNavigationController : UINavigationController
@property (weak) RCDevice * device;
@end
