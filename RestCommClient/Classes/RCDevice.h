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

/**
 * Connectivity Type
 */
typedef enum {
    RCDeviceConnectivityTypeNone = 0,
    RCDeviceConnectivityTypeWifi,  /**< Device is connected via Wifi (given that RCDeviceState is Ready or Busy) */
    RCDeviceConnectivityTypeCellularData,  /**< Device is connected via Cellular Data (given that RCDeviceState is Ready or Busy) */
} RCDeviceConnectivityType;

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
 *  As far as instant messages are concerned you can send a message using [RCDevice sendMessage:] and you will be notified of an incoming message
 *  via [RCDeviceDelegate device:didReceiveIncomingMessage:withParams:] delegate method.
 */
@interface RCDevice : NSObject
/**
 *  @abstract Device state
 */
@property (nonatomic) RCDeviceState state;

/**
 *  @abstract Device connectivity type, given that RCDeviceState is Ready or Busy
 */
@property (nonatomic) RCDeviceConnectivityType connectivityType;

/**
 *  @abstract Device capabilities (**Not Implemented yet**)
 */
@property (nonatomic, readonly) NSDictionary* capabilities;

/**
 *  @abstract Delegate that will be receiving RCDevice events described at RCDeviceDelegate protocol
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
 *  Initialize a new RCDevice object with the given parameters
 *
 *  @param parameters      Parameters for the Device entity. Possible keys: <br>
 *    <b>aor</b>: identity (or address of record) for the client, like <i>'sip:ios-sdk@cloud.restcomm.com'</i> <br>
 *    <b>password</b>: password for the client <br>
 *    <b>turn-enabled</b>: should TURN be enabled? <br>
 *    <b>turn-url</b>: TURN url if you want to use TURN for webrtc ICE negotiation, like <i>'https://turn.provider.com/turn'</i> <br>
 *    <b>turn-username</b>: TURN username <br>
 *    <b>turn-password</b>: TURN password <br>
 *    <b>registrar</b>: Restcomm instance to use, like <i>'cloud.restcomm.com'</i>. Leave empty for registrar-less mode <br>
 *    <b>signaling-secure</b>: Should signaling traffic be encrypted? For traffic to be encrypted the 'signaling-certificate-dir' below should be provided as well <br>
 *    <b>signaling-certificate-dir</b>: Directory where files agent.pem and cafile.pem are installed inside the App bundle needed when TLS is to be used for signaling. agent.pem contains the private key and certificate to be used by the signaling facilities. cafile.pem is a file containing all trusted certs
 *  @param delegate        Delegate of RCDevice
 *
 *  @return Newly initialized RCDevice object
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
 *  @abstract Retrieve RCDevice parameters
 *
 *  @return RCDevice parameters
 */
- (NSDictionary*)getParams;

/**
 *  @abstract Create an outgoing connection to an endpoint
 *
 *  @param parameters Parameters for the outgoing connection. Possible keys: <br>
 *    <b>username</b>: Who is the called number, like <i>'+1235'</i> or <i>'sip:+1235@cloud.restcomm.com'</i> <br>
 *    <b>video-enabled</b>: Whether we want WebRTC video enabled or not <br>
 *    <b>sip-headers</b>: An optional NSDictionary of custom SIP headers we want to add to the INVITE <br>
 *  @param delegate   The delegate object that will receive events when the connection state changes
 *
 *  @return An RCConnection object representing the new connection
 */
- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;

/**
 *  @abstract Send a text message 
 *
 *  @param parameters  Message parameters. Possible keys are:  <br>
 *    <b>username</b>: Who is the recepient of the text message, like <i>'sip:+1235@cloud.restcomm.com'</i> <br>
 *    <b>message</b>: Content of the message <br>
 *    <b>sip-headers</b>: An optional NSDictionary of custom SIP headers we want to add to the MESSAGE <br>
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
 *  @param params Dictionary of key/value pairs of the parameters that will be updated: <br>
 *    <b>aor</b>: identity (or address of record) for the client, like <i>'sip:ios-sdk@cloud.restcomm.com'</i> <br>
 *    <b>password</b>: password for the client <br>
 *    <b>turn-enabled</b>: should TURN be enabled? <br>
 *    <b>turn-url</b>: TURN url if you want to use TURN for webrtc ICE negotiation, like <i>'https://turn.provider.com/turn'</i> <br>
 *    <b>turn-username</b>: TURN username <br>
 *    <b>turn-password</b>: TURN password <br>
 *    <b>registrar</b>: Restcomm instance to use, like <i>'sip:cloud.restcomm.com'</i>. Leave empty for registrar-less mode <br>
 *    <b>signaling-secure</b>: Should signaling traffic be encrypted? For traffic to be encrypted the 'signaling-certificate-dir' below should be provided as well <br>
 *    <b>signaling-certificate-dir</b>: Directory where files agent.pem and cafile.pem are installed inside the App bundle needed when TLS is to be used for signaling. agent.pem is the client/server cert containing key and certificate to be used by the signaling facilities. cafile.pem is a file containing all trusted certs
 *
 *  @return If update of parameters was successful. Typical reason to fail is connectivity issues.
 */
- (BOOL) updateParams:(NSDictionary*)params;

// To be used internally by the library -not for application usage
- (void)clearCurrentConnection;

/* DEBUG:
-(void)startSofia;
-(void)stopSofia;
 */

@end

