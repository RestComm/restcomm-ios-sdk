//
//  RCConnection.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCConnectionDelegate.h"

typedef enum
{
	RCConnectionStatePending = 0,
	RCConnectionStateConnecting,
	RCConnectionStateConnected,
	RCConnectionStateDisconnected
} RCConnectionState;


extern NSString* const RCConnectionIncomingParameterFromKey;
extern NSString* const RCConnectionIncomingParameterToKey;
extern NSString* const RCConnectionIncomingParameterAccountSIDKey;
extern NSString* const RCConnectionIncomingParameterAPIVersionKey;
extern NSString* const RCConnectionIncomingParameterCallSIDKey;

@class SipManager;
@interface RCConnection : NSObject
@property (nonatomic, readonly) RCConnectionState state;
@property (nonatomic, readonly, getter=isIncoming) BOOL incoming;
@property (nonatomic, readonly) NSDictionary* parameters;
@property (nonatomic, assign) id<RCConnectionDelegate> delegate;
@property (nonatomic, getter = isMuted) BOOL muted;
// which device owns this connection
@property SipManager * sipManager;


// #new
- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate;
- (void)accept;
- (void)ignore;
- (void)reject;
- (void)disconnect;
- (void)sendDigits:(NSString*)digits;

@end
