/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2015, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * For questions related to commercial use licensing, please contact sales@telestax.com.
 *
 */

#import <Foundation/Foundation.h>

//#import "RCDeviceDelegate.h"
#import "RCConnectionDelegate.h"

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
@protocol SipManagerDeviceDelegate;
@protocol RCDeviceDelegate;

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
 *  @abstract Device state
 */
@property (nonatomic) RCDeviceState state;

/**
 *  @abstract Device capabilities (**Not Implemented yet**)
 */
@property (nonatomic, readonly) NSDictionary* capabilities;

/**
 *  @abstract Delegate that will be receiving RCDevice events described at RCDeviceDelegate
 */
@property (nonatomic, assign) id<RCDeviceDelegate> delegate;

/**
 *  @abstract Is sound for incoming connections enabled
 */
@property (nonatomic) BOOL incomingSoundEnabled;

/**
 *  @abstract Is sound for outgoing connections enabled
 */
@property (nonatomic) BOOL outgoingSoundEnabled;

/**
 *  @abstract Is sound for disconnect enabled (**Not Implemented yet**)
 */
@property (nonatomic) BOOL disconnectSoundEnabled;

/**
 *  Initialize a new RCDevice object with parameters
 *
 *  @param parameters      Parameters
 *  @param delegate        Delegate of RCDevice
 *
 *  @return Newly initialized object
 */
- (id)initWithParams:(NSDictionary*)parameters delegate:(id<RCDeviceDelegate>)delegate;

/**
 *  Initialize a new RCDevice object with capability token
 *
 *  @param capabilityToken Capability Token
 *  @param delegate        Delegate of RCDevice
 *
 *  @return Newly initialized object
 */
- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate;

/**
 *  @abstract Start listening for incoming connections (RCDevice is configured to listen once it is instantiated)
 */
- (void)listen;

/**
 *  @abstract Stop listening for incoming connections
 */
- (void)unlisten;

/**
 *  @abstract Update Capability Token
 *
 *  @param capabilityToken New Capability Token (**Not Implemented**)
 */
- (void)updateCapabilityToken:(NSString*)capabilityToken;

/**
 *  @abstract Retrieve parameters
 *
 *  @return RCDevice parameters
 */
- (NSDictionary*)getParams;

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
 *  @param parameters  Message parameters. Keys are: 'message' for content, 
 *                     'username' for recepient, 'sip-headers' for optional custom SIP headers
 *
 *  @return A boolean whether message was sent or not.
 */
- (BOOL)sendMessage:(NSDictionary*)parameters;

/**
 *  @abstract Disconnect all connections
 */
- (void)disconnectAll;

/**
 *  @abstract Update RCDevice parameters
 *
 *  @param params Dictionary of key/value pairs of the parameters that will be updated
 *
 *  @return If update of parameters was successful. Typical reason to fail is connectivity issues
 */
- (BOOL) updateParams:(NSDictionary*)params;

/* DEBUG:
-(void)startSofia;
-(void)stopSofia;
 */

@end

