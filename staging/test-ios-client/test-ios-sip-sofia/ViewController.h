//
//  ViewController.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RestCommClient.h"

//@class SipManager;
@interface ViewController : UIViewController<RCDeviceDelegate,RCConnectionDelegate>
//@property SipManager * sipManager;

@property (nonatomic,retain) RCDevice* device;
@property (nonatomic,retain) RCConnection* connection;
@property (nonatomic,retain) RCConnection* pendingIncomingConnection;
@property NSMutableDictionary * parameters;
@end
