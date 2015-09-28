//
//  MessageTableViewController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/23/15.
//  Copyright © 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RestCommClient.h"

@protocol MessageDelegate;

@interface MessageTableViewController : UITableViewController<UIAlertViewDelegate>
- (void)appendToDialog:(NSString*)msg sender:(NSString*)sender;

@property (weak) RCDevice * device;
@property NSMutableDictionary * parameters;
@property (weak) id<MessageDelegate> delegate;
@end

@protocol MessageDelegate <NSObject>
- (void)messageViewController:(MessageTableViewController*)messageViewController
       didAddContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri;
@end