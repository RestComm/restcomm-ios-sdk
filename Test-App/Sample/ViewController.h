//
//  ViewController.h
//  Sample
//
//  Created by Antonis Tsakiridis on 10/26/16.
//  Copyright © 2016 Telestax Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RestCommClient.h"

@interface ViewController : UIViewController
@property (nonatomic,retain) RCDevice* device;
@property (nonatomic,retain) RCConnection* connection;
@property NSMutableDictionary * parameters;
@property BOOL isInitialized;
@property BOOL isRegistered;

@end

