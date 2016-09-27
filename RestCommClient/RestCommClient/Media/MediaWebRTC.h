/*
 * libjingle
 * Copyright 2014 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
#import "WebRTC/RTCPeerConnectionFactory.h"
#import "ARDCEODTURNClient.h"
#import "XirsysTURNClient.h"
//#import "RTCPeerConnectionDelegate.h"
//#import "WebRTC/RTCSessionDescriptionDelegate.h"

@protocol MediaDelegate;

typedef NS_ENUM(NSInteger, ARDAppClientState) {
    // Disconnected from servers.
    kARDAppClientStateDisconnected,
    // Connecting to servers.
    kARDAppClientStateConnecting,
    // Connected to servers.
    kARDAppClientStateConnected,
};

typedef enum {
    kARDSignalingMessageTypeCandidate,
    kARDSignalingMessageTypeOffer,
    kARDSignalingMessageTypeAnswer,
    kARDSignalingMessageTypeBye,
} ARDSignalingMessageType;

@interface MediaWebRTC : NSObject  //<RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
- (id)initWithDelegate:(id<MediaDelegate>)mediaDelegate parameters:(NSDictionary*)parameters;
// TODO: change the name to something more appropriate
- (void)connect:(NSString*)sofia_handle sdp:(NSString*)sdp isInitiator:(BOOL)initiator withVideo:(BOOL)videoAllowed;
- (void)disconnect;
- (void)processSignalingMessage:(const char *)message type:(int)type;
- (void)mute;
- (void)unmute;
- (void)muteVideo;
- (void)unmuteVideo;


// our delegate is SIP Manager
@property (weak) id<MediaDelegate> mediaDelegate;
@property(nonatomic, readonly) ARDAppClientState state;
// for now let's keep just one hanle -in a complex application we could have more
@property NSString * sofia_handle;
@property NSString * sdp;
@property BOOL videoAllowed;
@property BOOL candidatesGathered;
@property NSDictionary* parameters;

@end

// use this protocol for WebRTC -> Sofia communication
@protocol MediaDelegate <NSObject>
// when WebRTC module knows the SDP string it needs to communicate it to its delegate (i.e. SIP Manager) who in turn will notify SIP sofia
- (void)mediaController:(MediaWebRTC *)mediaController didCreateSdp:(NSString *)sdpString isInitiator:(BOOL)initiator;
- (void)mediaController:(MediaWebRTC *)mediaController didError:(NSError*)error;
- (void)mediaController:(MediaWebRTC *)mediaController didReceiveLocalVideoTrack:(RTCVideoTrack *)videoTrack;
- (void)mediaController:(MediaWebRTC *)mediaController didReceiveRemoteVideoTrack:(RTCVideoTrack *)videoTrack;
- (void)mediaController:(MediaWebRTC *)mediaController didIceConnectAsInitiator:(BOOL)initiator;

//- (void)peerDisconnected:(MediaWebRTC *)media withData:(NSString *)data;
@end
