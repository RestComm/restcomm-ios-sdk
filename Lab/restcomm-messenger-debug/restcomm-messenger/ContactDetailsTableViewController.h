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
#import "ContactUpdateTableViewController.h"

@protocol ContactDetailsDelegate;

@interface ContactDetailsTableViewController : UITableViewController<CallDelegate, ContactUpdateDelegate>
@property (weak) RCDevice * device;
@property NSString * alias;
@property NSString * sipUri;
@property (weak) id<ContactDetailsDelegate> delegate;
@end

@protocol ContactDetailsDelegate <NSObject>
- (void)contactDetailsViewController:(ContactDetailsTableViewController*)contactDetailsViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri;
@end