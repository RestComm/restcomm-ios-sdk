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

typedef enum
{
	RCDeviceStateOffline = 0,
	RCDeviceStateReady,
	RCDeviceStateBusy
} RCDeviceState;

extern NSString* const RCDeviceCapabilityIncomingKey;
extern NSString* const RCDeviceCapabilityOutgoingKey;
extern NSString* const RCDeviceCapabilityExpirationKey;
extern NSString* const RCDeviceCapabilityAccountSIDKey;
extern NSString* const RCDeviceCapabilityApplicationSIDKey;
extern NSString* const RCDeviceCapabilityApplicationParametersKey;
extern NSString* const RCDeviceCapabilityClientNameKey;


@class RCConnection;
//@protocol SipManagerDelegate;

@interface RCDevice : NSObject <SipManagerDelegate,NSURLConnectionDelegate>

@property (nonatomic, readonly) RCDeviceState state;
@property (nonatomic, readonly) NSDictionary* capabilities;
@property (nonatomic, assign) id<RCDeviceDelegate> delegate;
@property (nonatomic) BOOL incomingSoundEnabled;
@property (nonatomic) BOOL outgoingSoundEnabled;
@property (nonatomic) BOOL disconnectSoundEnabled;

- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate;
- (void)listen;
- (void)unlisten;
- (void)updateCapabilityToken:(NSString*)capabilityToken;
- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;
- (void)disconnectAll;

@end