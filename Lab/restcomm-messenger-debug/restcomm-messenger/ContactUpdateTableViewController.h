//
//  ContactUpdateTableViewController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RestCommClient.h"

@protocol ContactUpdateDelegate;

@interface ContactUpdateTableViewController : UITableViewController

typedef enum {
    CONTACT_EDIT_TYPE_CREATION,
    CONTACT_EDIT_TYPE_MODIFICATION,
} ContactEditType;

@property (weak) RCDevice * device;
@property NSString * alias;
@property NSString * sipUri;
@property ContactEditType contactEditType;
@property (weak) id<ContactUpdateDelegate> delegate;
@end

@protocol ContactUpdateDelegate <NSObject>
- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri;
@end