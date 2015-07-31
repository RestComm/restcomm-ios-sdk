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
#import "RTCVideoTrack.h"

@interface RCConnection ()
// private methods
// which device owns this connection
@property RCDevice * device;
@property AVAudioPlayer * ringingPlayer;
@property AVAudioPlayer * callingPlayer;
@end

@implementation RCConnection
@synthesize state;
@synthesize muted;

NSString* const RCConnectionIncomingParameterFromKey = @"RCConnectionIncomingParameterFromKey";
NSString* const RCConnectionIncomingParameterToKey = @"RCConnectionIncomingParameterToKey";
NSString* const RCConnectionIncomingParameterAccountSIDKey = @"RCConnectionIncomingParameterAccountSIDKey";
NSString* const RCConnectionIncomingParameterAPIVersionKey = @"RCConnectionIncomingParameterAPIVersionKey";
NSString* const RCConnectionIncomingParameterCallSIDKey = @"RCConnectionIncomingParameterCallSIDKey";

- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate andDevice:(RCDevice*)device
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.sipManager = nil;
        self.state = RCConnectionStateDisconnected;
        self.device = device;
        muted = NO;
        
        [self prepareSounds];
    }
    return self;
}


- (void)accept:(NSDictionary*)parameters
{
    NSLog(@"[RCConnection accept]");

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
    NSLog(@"[RCConnection ignore]");
   
}

- (void)reject
{
    NSLog(@"[RCConnection reject]");
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
    NSLog(@"[RCConnection disconnect]");
    if (self.state == RCConnectionStateConnecting) {
        if (!self.isIncoming) {
            // for outgoing calls in state connecting (i.e. ringing), treat disconnect as cancel
            [self.sipManager cancel];
        }
        else {
            // for incoming calls in state connecting (i.e. ringing), treat disconnect as decline
            [self.sipManager decline];
        }
    }
    else if (self.state == RCConnectionStateConnected) {
        [self.sipManager bye];
    }
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
}

- (void)sendDigits:(NSString*)digits
{
    NSLog(@"[RCConnection sendDigits]");
    
}

- (void)outgoingRinging:(SipManager *)sipManager
{
    if (self.device.outgoingSoundEnabled == true) {
        [self.callingPlayer play];
    }
    [self setState:RCConnectionStateConnecting];
    [self.delegate connectionDidStartConnecting:self];
}

- (void)outgoingEstablished:(SipManager *)sipManager
{
    if ([self.callingPlayer isPlaying]) {
        [self.callingPlayer stop];
        self.callingPlayer.currentTime = 0.0;
    }
    
    [self setState:RCConnectionStateConnected];
    [self.delegate connectionDidConnect:self];
}

- (void)outgoingDeclined:(SipManager *)sipManager
{
    if ([self.callingPlayer isPlaying]) {
        [self.callingPlayer stop];
        self.callingPlayer.currentTime = 0.0;
    }
    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidGetDeclined:self];
    self.device.state = RCDeviceStateReady;
}

- (void)incomingBye:(SipManager *)sipManager
{
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }

    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidDisconnect:self];
    self.device.state = RCDeviceStateReady;
}

- (void)incomingCancelled:(SipManager *)sipManager
{
    if ([self.ringingPlayer isPlaying]) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }

    self.state = RCConnectionStateDisconnected;
    [self.delegate connectionDidCancel:self];
    self.device.state = RCDeviceStateReady;
}

- (void)sipManager:(SipManager *)sipManager receivedLocalVideo:(RTCVideoTrack *)localView
{
    [self.delegate connection:self didReceiveLocalVideo:localView];
}

- (void)sipManager:(SipManager *)sipManager receivedRemoteVideo:(RTCVideoTrack *)remoteView
{
    [self.delegate connection:self didReceiveRemoteVideo:remoteView];
}

- (void)setMuted:(BOOL)isMuted
{
    // avoid endless loop
    muted = isMuted;
    [self.sipManager setMuted:isMuted];

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
