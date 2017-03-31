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

#import <AVFoundation/AVFoundation.h>   // sounds
#import "RCDevice.h"
#import "RCConnection.h"
#import "SipManager.h"
#import "WebRTC/RTCVideoTrack.h"
#import "RCUtilities.h"

#include "common.h"
#include "RestCommClient.h"

@interface RCConnection () <SipManagerConnectionDelegate>
// private methods
// which device owns this connection
@property RCDevice * device;
@property AVAudioPlayer * ringingPlayer;
@property AVAudioPlayer * callingPlayer;
@property BOOL cancelPending;
@end

@implementation RCConnection
@synthesize state;
@synthesize muted;
@synthesize videoMuted;
@synthesize speaker;


NSString* const RCConnectionIncomingParameterFromKey = @"RCConnectionIncomingParameterFromKey";
NSString* const RCConnectionIncomingParameterToKey = @"RCConnectionIncomingParameterToKey";
NSString* const RCConnectionIncomingParameterAccountSIDKey = @"RCConnectionIncomingParameterAccountSIDKey";
NSString* const RCConnectionIncomingParameterAPIVersionKey = @"RCConnectionIncomingParameterAPIVersionKey";
NSString* const RCConnectionIncomingParameterCallSIDKey = @"RCConnectionIncomingParameterCallSIDKey";

- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate andDevice:(RCDevice*)device
         andSipManager:(SipManager*)sipManager
           andIncoming:(BOOL)incoming
              andState:(RCConnectionState)connectionState
         andParameters:(NSDictionary*)parameters
{
    RCLogNotice("[RCConnection initWithDelegate: ... andIncoming:%d andState:%d andParameters:%s]", incoming, connectionState, [[RCUtilities stringifyDictionary:parameters] UTF8String]);
    
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.sipManager = sipManager;
        self.incoming = incoming;
        self.state = connectionState;
        _parameters = parameters;
        self.device = device;
        muted = NO;
        self.cancelPending = NO;
        
        [self prepareSounds];
    }
    return self;
}

- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate andDevice:(RCDevice*)device
{
    return [self initWithDelegate:delegate andDevice:device andSipManager:nil andIncoming:NO andState:RCConnectionStateDisconnected andParameters:nil];
}

- (void)dealloc {
    RCLogNotice("[RCConnection dealloc]");
}

- (void)accept:(NSDictionary*)parameters
{
    RCLogNotice("[RCConnection accept: %s]", [[RCUtilities stringifyDictionary:parameters] UTF8String]);
    
    if (self.isIncoming && self.state == RCConnectionStateConnecting) {
        BOOL videoAllowed = NO;
        if ([parameters objectForKey:@"video-enabled"]) {
            videoAllowed = [[parameters objectForKey:@"video-enabled"] boolValue];
        };

        [self.sipManager answerWithVideo:videoAllowed];
        self.state = RCConnectionStateConnected;
    }
    
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }
}

- (void)ignore
{
    RCLogNotice("[RCConnection ignore]");
}

- (void)reject
{
    RCLogNotice("[RCConnection reject]");
    if (self.isIncoming && self.state == RCConnectionStateConnecting) {
        [self.sipManager decline];
        self.device.state = RCDeviceStateReady;
    }
    
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }
}

- (void)disconnect
{
    RCLogNotice("[RCConnection disconnect]");
    if (self.state == RCConnectionStateConnecting) {
        if (!self.isIncoming) {
            // for outgoing calls in state connecting (i.e. ringing), treat disconnect as cancel
            NSLog(@"[RCConnection disconnect:cancel]");

            [self.sipManager cancel];
        }
        else {
            // for incoming calls in state connecting (i.e. ringing), treat disconnect as decline
            NSLog(@"[RCConnection disconnect:decline]");

            [self.sipManager decline];
        }
    }
    else if (self.state == RCConnectionStateConnected) {
        NSLog(@"[RCConnection disconnect:bye]");

        [self.sipManager bye];
    }
    else if (self.state == RCConnectionStatePending) {
        // SIP doesn't support canceling before receiving provisional response (i.e. 180 Ringing, etc).
        // Let's mark for cancelation once we get that response
        if (!self.isIncoming) {
            //NSLog(@"[RCConnection disconnect:cancelPending]");
            self.cancelPending = YES;
        }
    }
    
    RCLogNotice("[RCConnection disconnect] before disconnectMedia");
    [self.sipManager disconnectMedia];
    RCLogNotice("[RCConnection disconnect] after disconnectMedia");

    self.state = RCConnectionStateDisconnected;
    self.device.state = RCDeviceStateReady;
    if ([self.callingPlayer isPlaying]) {
        [self.callingPlayer stop];
        self.callingPlayer.currentTime = 0.0;
    }
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }
    
    [self handleDisconnected];
}

- (void)sendDigits:(NSString*)digits
{
    RCLogNotice("[RCConnection sendDigits]");
    if (self.state == RCConnectionStateConnected) {
        [self.sipManager sendDtmfDigits:digits];
    }
    else {
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                       code:ERROR_SENDING_DIGITS
                                                   userInfo:@{ NSLocalizedDescriptionKey: @"Error sending DTMF digits: Invalid RCConnection state" }];
        [self.delegate connection:self didFailWithError:error];
    }
}

- (void)setMuted:(BOOL)isMuted
{
    RCLogNotice("[RCConnection setMuted]");
    // avoid endless loop
    muted = isMuted;
    [self.sipManager setMuted:isMuted];
    
}

- (void)setVideoMuted:(BOOL)isMuted
{
    RCLogNotice("[RCConnection setVideoMuted]");
    // avoid endless loop
    videoMuted = isMuted;
    [self.sipManager setVideoMuted:isMuted];
    
}

- (void)setSpeaker:(BOOL)isSpeaker
{
    RCLogNotice("[RCConnection setSpeaker]");
    // avoid endless loop
    speaker = isSpeaker;
    [self.sipManager setSpeaker:isSpeaker];
    
}

- (BOOL)isMuted
{
    return self.sipManager.muted;
}

// this is a notification from RCDevice that we have an incoming connection so that
// we can start the sounds (to avoid sharing the same audio facilities between RCDevice and RCConnection)
- (void)incomingRinging
{
    if (self.device.incomingSoundEnabled == true) {
        [self.ringingPlayer play];
    }
}

#pragma mark SipManager Delegate methods
- (void)sipManagerDidReceiveOutgoingRinging:(SipManager*)sipManager
{
    RCLogNotice("[RCConnection sipManagerDidReceiveOutgoingRinging]");
    if (self.cancelPending) {
        //NSLog(@"[RCConnection outgoingRinging:canceling]");
        [self.sipManager cancel];
        return;
    }
    
    if (self.device.outgoingSoundEnabled == true) {
        [self.callingPlayer play];
    }
    [self setState:RCConnectionStateConnecting];
    [self.delegate connectionDidStartConnecting:self];
}

- (void) handleDisconnected
{
    [self.device clearCurrentConnection];
}

- (void)sipManagerDidReceiveOutgoingEstablished:(SipManager*)sipManager
{
    RCLogNotice("[RCConnection sipManagerDidReceiveOutgoingEstablished]");

    if ([self.callingPlayer isPlaying]) {
        [self.callingPlayer stop];
        self.callingPlayer.currentTime = 0.0;
    }
    
    if (self.cancelPending) {
        // if the cancel when we got the ringing didn't make it on time
        // then we will have received a 200 OK established. In that case
        // we need to terminate the call with a BYE
        //NSLog(@"[RCConnection outgoingEstablished:bye]");
        [self.sipManager bye];
        self.cancelPending = NO;
        return;
    }
    
    [self setState:RCConnectionStateConnected];
    [self.delegate connectionDidConnect:self];
}

- (void)sipManagerDidReceiveIncomingEstablished:(SipManager*)sipManager
{
    RCLogNotice("[RCConnection sipManagerDidReceiveIncomingEstablished]");
    
    //[self setState:RCConnectionStateConnected];
    [self.delegate connectionDidConnect:self];
}

// we got an 487 Cancelled to our outgoing invite
- (void)sipManagerDidReceiveOutgoingCancelled:(SipManager*)sipManager;
{
    RCLogNotice("[RCConnection sipManagerDidReceiveOutgoingCancelled]");
    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidDisconnect:self];
    self.device.state = RCDeviceStateReady;
    [self handleDisconnected];
}

- (void)sipManagerDidReceiveOutgoingDeclined:(SipManager*)sipManager;
{
    RCLogNotice("[RCConnection sipManagerDidReceiveOutgoingDeclined]");

    if ([self.callingPlayer isPlaying]) {
        [self.callingPlayer stop];
        self.callingPlayer.currentTime = 0.0;
    }
    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidGetDeclined:self];
    self.device.state = RCDeviceStateReady;
    [self handleDisconnected];
}

- (void)sipManagerDidReceiveBye:(SipManager*)sipManager;
{
    RCLogNotice("[RCConnection sipManagerDidReceiveBye]");
    
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }
    
    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidDisconnect:self];
    
    // we need this check to avoid setting state to ready when we have already been shutdown
    if (self.device.state != RCDeviceStateOffline) {
        self.device.state = RCDeviceStateReady;
    }
    [self handleDisconnected];
}

- (void)sipManagerDidReceiveIncomingCancelled:(SipManager*)sipManager;
{
    RCLogNotice("[RCConnection sipManagerDidReceiveIncomingCancelled]");

    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }

    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidCancel:self];
    self.device.state = RCDeviceStateReady;
    [self handleDisconnected];
}

- (void)sipManager:(SipManager*)sipManager didReceiveLocalVideo:(RTCVideoTrack *)localView;
{
    RCLogNotice("[RCConnection didReceiveLocalVideo]");
    [self.delegate connection:self didReceiveLocalVideo:localView];
}

- (void)sipManager:(SipManager*)sipManager didReceiveRemoteVideo:(RTCVideoTrack *)remoteView;
{
    RCLogNotice("[RCConnection didReceiveRemoteVideo]");
    [self.delegate connection:self didReceiveRemoteVideo:remoteView];
}

- (void)sipManager:(SipManager*)sipManager didMediaError:(NSError *)error
{
    RCLogNotice("[RCConnection didMediaError: %s]", [[RCUtilities stringifyDictionary:[error userInfo]] UTF8String]);
    [self disconnect];
    [self.delegate connection:self didFailWithError:error];
}

- (void)sipManager:(SipManager*)sipManager didSignallingError:(NSError *)error
{
    RCLogNotice("[RCConnection didSignallingError: %s]", [[RCUtilities stringifyDictionary:[error userInfo]] UTF8String]);
    [self disconnect];
    [self.delegate connection:self didFailWithError:error];
}

#pragma mark Helpers
- (void)prepareSounds
{
    // ringing
    NSString * filename = @"ringing.mp3";
    // we are assuming the extension will always be the last 3 letters of the filename
    NSString * file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                                      ofType:[filename substringFromIndex:[filename length] - 3]];
    NSError *error;
    
    if (file) {
        self.ringingPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
        if (!self.ringingPlayer) {
            NSLog(@"Error: %@", [error description]);
            return;
        }
        self.ringingPlayer.numberOfLoops = -1; // repeat forever
    }
    
    // calling
    filename = @"calling.mp3";
    // we are assuming the extension will always be the last 3 letters of the filename
    file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                           ofType:[filename substringFromIndex:[filename length] - 3]];
    
    if (file) {
        self.callingPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
        if (!self.callingPlayer) {
            NSLog(@"Error: %@", [error description]);
            return;
        }
        self.callingPlayer.numberOfLoops = -1; // repeat forever
    }
}

@end
