//
//  RCConnection.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCConnectionDelegate.h"
#import "SipManager.h"

/** @file RCConnection.h */

/**
 * Connection State
 */
typedef enum
{
	RCConnectionStatePending = 0,  /**< Connection is in state pending */
	RCConnectionStateConnecting,  /**< Connection is in state connecting */
	RCConnectionStateConnected,  /**< Connection is in state connected */
	RCConnectionStateDisconnected  /**< Connection is in state disconnected */
} RCConnectionState;


extern NSString* const RCConnectionIncomingParameterFromKey;
extern NSString* const RCConnectionIncomingParameterToKey;
extern NSString* const RCConnectionIncomingParameterAccountSIDKey;
extern NSString* const RCConnectionIncomingParameterAPIVersionKey;
extern NSString* const RCConnectionIncomingParameterCallSIDKey;

@class SipManager;

/**
 *  Represents call either incoming or outgoing
 */
@interface RCConnection : NSObject<SipManagerConnectionDelegate>

/**
 *  State of the connection
 */
@property RCConnectionState state;

/**
 *  True if connection is incoming; false otherwise
 */
@property (nonatomic, getter=isIncoming) BOOL incoming;

/**
 *  Connection parameters
 */
@property (nonatomic, readonly) NSDictionary* parameters;

/**
 *  Delegate that will be receiving RCConnection events
 */
@property (nonatomic, assign) id<RCConnectionDelegate> delegate;

/**
 *  Is connection currently muted?
 */
@property (nonatomic, getter = isMuted) BOOL muted;


/**
 *  Initialize a new RCConnection object
 *
 *  @param delegate Delegate of RCConnection
 *
 *  @return Newly initialized object
 */
- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate;

/**
 *  Accept an incoming connection that is ringing. The connection state changes to 'RCConnectionStateConnected'
 */
- (void)accept;

/**
 *  Ignore connection (not implemented)
 */
- (void)ignore;

/**
 *  Reject an incoming connection
 */
- (void)reject;

/**
 *  Disconnect a connection that is in state 'RCConnectionStateConnecting' or 'RCConnectionStateConnected'
 */
- (void)disconnect;

/**
 *  Send DTMF tones over a connection that is in state 'RCConnectionStateConnected' (not implemented)
 *
 *  @param digits A string of digits that will be sent
 */
- (void)sendDigits:(NSString*)digits;

// avoid reference cycle
@property (weak) SipManager * sipManager;

@end
