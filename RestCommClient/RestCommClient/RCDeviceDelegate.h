//
//  RCDeviceDelegate.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

//#import <Foundation/Foundation.h>

@class RCDevice;
@class RCConnection;
@class RCPresenceEvent;

@protocol RCDeviceDelegate<NSObject>

@required
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error;

@optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device;
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection;
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent;
@end