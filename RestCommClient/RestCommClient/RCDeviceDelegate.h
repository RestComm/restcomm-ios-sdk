//
//  RCDeviceDelegate.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

@class RCDevice;
@class RCConnection;
@class RCPresenceEvent;

/**
 *  RCDevice notifies its delegate for events defined in this delegate protocol
 */
@protocol RCDeviceDelegate<NSObject>
@required
/**
 *  Device stoped listening for incoming connections
 *
 *  @param device Device of interest
 *  @param error  The reason it stoped
 */
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error;

@optional
/**
 *  Device started listening for incoming connections
 *
 *  @param device Device of interest
 */
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device;

/**
 *  Device received incoming connection
 *
 *  @param device     Device of interest
 *  @param connection Newly established connection
 */
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection;

/**
 *  Device received presence update (TODO)
 *
 *  @param device        Device of interest
 *  @param presenceEvent Presence event
 */
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent;

/**
 *  Device received incoming instant message
 *
 *  @param device  Device of interest
 *  @param message Instant message
 */
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message;
@end