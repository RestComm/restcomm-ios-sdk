//
//  ToastController.h
//  restcomm-olympus
//
//  Created by Antonis Tsakiridis on 4/26/16.
//  Copyright © 2016 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ToastController : NSObject
+ (id)sharedInstance;
- (void)showToastWithText:(NSString*)text withDuration:(float)duration;
@end
