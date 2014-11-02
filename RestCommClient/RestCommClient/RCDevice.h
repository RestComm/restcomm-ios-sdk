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

/** @file RCDevice.h */

/**
 * Device State
 */
typedef enum {
    RCDeviceStateOffline = 0,  /**< Device is offline */
	RCDeviceStateReady,  /**< Device is ready to make and receive connections */
	RCDeviceStateBusy  /**< Device is busy */
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
 *  RCDevice Represents an abstraction of a communications device able to make and receive calls, send and receive messages etc. Remember that
 *  in order to be notified of RestComm Client events you need to set a delegate to RCDevice and implement the applicable methods.
 *  If you want to initiate a media connection towards another party you use [RCDevice connect:delegate:] which returns an RCConnection object representing
 *  the new outgoing connection. From then on you can act on the new connection by applying RCConnection methods on the handle you got from [RCDevice connect:delegate:].
 *  If there’s an incoming connection you will be notified by [RCDeviceDelegate device:didReceiveIncomingConnection:] delegate method. At that point you can use RCConnection methods to
 *  accept or reject the connection.
 *
 *  As far as instant messages are concerned you can send a message using [RCDevice sendMessage:to:] and you will be notified of an incoming message 
 *  via [RCDeviceDelegate device:didReceiveIncomingMessage:] delegate method.
 */
@interface RCDevice : NSObject<SipManagerDeviceDelegate, NSURLConnectionDelegate>
/**
 *  @abstract Device state (**Not Implemented yet**)
 */
@property (nonatomic, readonly) RCDeviceState state;

/**
 *  @abstract Device capabilities (**Not Implemented yet**)
 */
@property (nonatomic, readonly) NSDictionary* capabilities;

/**
 *  @abstract Delegate that will be receiving RCDevice events described at RCDeviceDelegate
 */
@property (nonatomic, assign) id<RCDeviceDelegate> delegate;

/**
 *  @abstract Is sound for incoming connections enabled (**Not Implemented yet**)
 */
@property (nonatomic) BOOL incomingSoundEnabled;

/**
 *  @abstract Is sound for outgoing connections enabled (**Not Implemented yet**)
 */
@property (nonatomic) BOOL outgoingSoundEnabled;

/**
 *  @abstract Is sound for disconnect enabled (**Not Implemented yet**)
 */
@property (nonatomic) BOOL disconnectSoundEnabled;

/**
 *  Initialize a new RCDevice object
 *
 *  @param capabilityToken Capability Token (**Not Implemented yet**)
 *  @param delegate        Delegate of RCDevice
 *
 *  @return Newly initialized object
 */
- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate;

/**
 *  @abstract Start listening for incoming connections (**Not Implemented yet** -RCDevice is configured to listen once it is instantiated)
 */
- (void)listen;

/**
 *  @abstract Stop listening for incoming connections (**Not Implemented yet**)
 */
- (void)unlisten;

/**
 *  @abstract Update Capability Token
 *
 *  @param capabilityToken New Capability Token (**Not Implemented**)
 */
- (void)updateCapabilityToken:(NSString*)capabilityToken;

/**
 *  @abstract Create an outgoing connection to an endpoint
 *
 *  @param parameters Connections such as the endpoint we want to connect to
 *  @param delegate   The delegate object that will receive events when the connection state changes
 *
 *  @return An RCConnection object representing the new connection
 */
- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;

/**
 *  @abstract Send an instant message to a an endpoint
 *
 *  @param message  Message text
 *  @param receiver Message receiver
 */
- (void)sendMessage:(NSString*)message to:(NSDictionary*)receiver;

/**
 *  @abstract Disconnect all connections (**Not implemented yet**)
 */
- (void)disconnectAll;

/**
 *  @abstract Update RCDevice parameters
 *
 *  @param params Dictionary of key/value pairs of the parameters that will be updated
 */
- (void) updateParams:(NSDictionary*)params;
@end

