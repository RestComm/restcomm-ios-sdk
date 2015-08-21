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
#import "../Media/MediaWebRTC.h"

@protocol SipManagerDeviceDelegate;
@protocol SipManagerConnectionDelegate;

@interface SipManager : NSObject<MediaDelegate>
- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate;
- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate andParams:(NSDictionary*)params;
// initialize Sofia, setup communication via pipe and enter event loop (notice that the event loop runs in a separate thread)
- (bool)eventLoop;
- (bool)register:(NSString*)registrar;
- (bool)unregister:(NSString*)registrar;
- (bool)message:(NSString*)msg to:(NSString*)recipient;
- (bool)invite:(NSString*)recipient withVideo:(BOOL)video;
- (bool)answerWithVideo:(BOOL)video;
- (bool)decline;
- (bool)authenticate:(NSString*)string;
- (bool)cancel;
- (bool)bye;
- (bool)cli:(NSString*)cmd;
- (bool)updateParams:(NSDictionary*)params;

@property (weak) id<SipManagerDeviceDelegate> deviceDelegate;
@property (weak) id<SipManagerConnectionDelegate> connectionDelegate;
@property MediaWebRTC * media;
@property NSMutableDictionary* params;
@property (nonatomic) BOOL muted;
@property BOOL videoAllowed;
@end

@protocol SipManagerDeviceDelegate <NSObject>
- (void)messageArrived:(SipManager *)sipManager withData:(NSString *)message from:(NSString*)from;
// 'ringing' for incoming connections
- (void)callArrived:(SipManager *)sipManager;
- (void)signallingInitialized:(SipManager *)sipManager;
@end

@protocol SipManagerConnectionDelegate <NSObject>
- (void)outgoingRinging:(SipManager *)sipManager;
- (void)outgoingEstablished:(SipManager *)sipManager;
// received BYE; either a response to an outgoing bye, or an incoming BYE
- (void)bye:(SipManager *)sipManager;
- (void)incomingCancelled:(SipManager *)sipManager;
// we got an 487 Cancelled to our outgoing invite
- (void)outgoingCancelled:(SipManager *)sipManager;
- (void)outgoingDeclined:(SipManager *)sipManager;
- (void)sipManager:(SipManager *)sipManager receivedLocalVideo:(RTCVideoTrack *)localView;
- (void)sipManager:(SipManager *)sipManager receivedRemoteVideo:(RTCVideoTrack *)remoteView;
//- (void)incomingRinging:(SipManager *)sipManager;
//- (void)incomingEstablished:(SipManager *)sipManager;
@end