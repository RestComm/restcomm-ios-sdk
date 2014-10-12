//
//  RCDevice.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCDeviceDelegate.h"
#import "RCConnectionDelegate.h"
#import "SipManager.h"

/**
 Device State
 */
typedef enum {
    RCDeviceStateOffline = 0,  /** Device is offline */
	RCDeviceStateReady,  /** Device is ready to make and receive connections */
	RCDeviceStateBusy  /** Device is busy */
} RCDeviceState;

extern NSString* const RCDeviceCapabilityIncomingKey;
extern NSString* const RCDeviceCapabilityOutgoingKey;
extern NSString* const RCDeviceCapabilityExpirationKey;
extern NSString* const RCDeviceCapabilityAccountSIDKey;
extern NSString* const RCDeviceCapabilityApplicationSIDKey;
extern NSString* const RCDeviceCapabilityApplicationParametersKey;
extern NSString* const RCDeviceCapabilityClientNameKey;


@class RCConnection;

/**
 *  Represents an abstraction of a communication device able to make and receive calls, send and receive messages etc
 */
@interface RCDevice : NSObject <SipManagerDeviceDelegate,NSURLConnectionDelegate>
/**
 *  Device state
 */
@property (nonatomic, readonly) RCDeviceState state;
/**
 *  Device capabilities
 */
@property (nonatomic, readonly) NSDictionary* capabilities;
/**
 *  Delegate that will be receiving RCDevice events
 */
@property (nonatomic, assign) id<RCDeviceDelegate> delegate;
/**
 *  Sound for incoming connections enabled
 */
@property (nonatomic) BOOL incomingSoundEnabled;
/**
 *  Sound for outgoing connections enabled
 */
@property (nonatomic) BOOL outgoingSoundEnabled;
/**
 *  Sound for disconnect enabled
 */
@property (nonatomic) BOOL disconnectSoundEnabled;
/**
 *  Initialize a new RCDevice object
 *
 *  @param capabilityToken Capability Token
 *  @param delegate        Delegate of RCDevice
 *
 *  @return Newly initialized object
 */
- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate;
/**
 *  Start listening for incoming connections
 */
- (void)listen;
/**
 *  Stop listening for incoming connections
 */
- (void)unlisten;
/**
 *  Update Capability Token
 *
 *  @param capabilityToken New Capability Token
 */
- (void)updateCapabilityToken:(NSString*)capabilityToken;
/**
 *  Create an outgoing connection to an endpoint
 *
 *  @param parameters Connections such as the endpoint we want to connect to
 *  @param delegate   The delegate object that will receive events when the connection state changes
 *
 *  @return An RCConnection object representing the new connection
 */
- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;
/**
 *  Send an instant message
 *
 *  @param message  Message text
 *  @param receiver Message receiver
 */
- (void)sendMessage:(NSString*)message to:(NSDictionary*)receiver;
/**
 *  Disconnect all connections
 */
- (void)disconnectAll;

/**
 *  Update RCDevice parameters
 *
 *  @param params Dictionary of key/value pairs of the parameters that will be updated
 */
- (void) updateParams:(NSDictionary*)params;

@end