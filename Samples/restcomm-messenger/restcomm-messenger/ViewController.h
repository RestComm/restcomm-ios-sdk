//
//  ViewController.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>   // sounds


#import "RestCommClient.h"

@interface ViewController : UIViewController<RCDeviceDelegate,RCConnectionDelegate>
@property (nonatomic,retain) RCDevice* device;
@property (nonatomic,retain) RCConnection* connection;
@property (nonatomic,retain) RCConnection* pendingIncomingConnection;
@property NSMutableDictionary * parameters;
@property AVAudioPlayer * messagePlayer;
@property AVAudioPlayer * ringingPlayer;
@end
