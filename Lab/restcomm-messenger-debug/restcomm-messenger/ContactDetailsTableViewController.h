//
//  ContactDetailsTableViewController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RestCommClient.h"
#import "CallViewController.h"

@interface ContactDetailsTableViewController : UITableViewController<CallDelegate>
@property (weak) RCDevice * device;
@property NSString * alias;
@property NSString * sipUri;
@end
