//
//  MessageViewController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 8/3/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RestCommClient.h"

@interface MessageViewController : UIViewController
- (void)appendToDialog:(NSString*)msg sender:(NSString*)sender;
@property (weak) RCDevice * device;
//@property (weak) id<MessageDelegate> delegate;
@property NSMutableDictionary * parameters;
@end

/*
@protocol MessageDelegate <NSObject>
- (void)messageViewController:(MessageViewController *)messageViewController didSendStatus:(NSString *)status subStatus:(NSString*)subStatus;
@end
*/