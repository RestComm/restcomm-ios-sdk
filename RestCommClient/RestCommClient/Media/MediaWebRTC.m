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

#import "ARDAppClient+Internal.h"
#import "MediaWebRTC.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "RTCICECandidate.h"
#import "RTCPeerConnection.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCSessionDescription.h"

@implementation MediaWebRTC

// TODO: update these properly
static NSString *kARDTurnRequestUrl =
    @"https://computeengineondemand.appspot.com"
    @"/turn?username=iapprtc&key=4080218913";
static NSString *kARDDefaultSTUNServerUrl =
    @"stun:stun.l.google.com:19302";

static NSString *kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger kARDAppClientErrorUnknown = -1;
//static NSInteger kARDAppClientErrorRoomFull = -2;
static NSInteger kARDAppClientErrorCreateSDP = -3;
static NSInteger kARDAppClientErrorSetSDP = -4;
//static NSInteger kARDAppClientErrorInvalidClient = -5;
//static NSInteger kARDAppClientErrorInvalidRoom = -6;

- (id)initWithDelegate:(id<MediaDelegate>)mediaDelegate
{
    self = [super init];
    if (self) {
        self.mediaDelegate = mediaDelegate;
        _isTurnComplete = NO;
        // for now we are always iniator
        _isInitiator = YES;

        //[self main];
    }
    return self;
}

// entry point for WebRTC handling
- (void) main:(NSString*)sofia_handle
{
    [RTCPeerConnectionFactory initializeSSL];
    self.sofia_handle = sofia_handle;
    
    NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
    _turnClient = [[ARDCEODTURNClient alloc] initWithURL:turnRequestURL];
    [self configure];
    
    // Request TURN
    __weak MediaWebRTC *weakSelf = self;
    [_turnClient requestServersWithCompletionHandler:^(NSArray *turnServers,
                                                       NSError *error) {
        if (error) {
            NSLog(@"Error retrieving TURN servers: %@", error);
        }
        MediaWebRTC *strongSelf = weakSelf;
        [strongSelf.iceServers addObjectsFromArray:turnServers];
        strongSelf.isTurnComplete = YES;
        [strongSelf startSignalingIfReady];
    }];
}

- (void) terminate
{
    [RTCPeerConnectionFactory deinitializeSSL];
}

- (void)configure {
    _factory = [[RTCPeerConnectionFactory alloc] init];
    //_messageQueue = [NSMutableArray array];
    _iceCandidates = [NSMutableArray array];
    _iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
}

- (RTCICEServer *)defaultSTUNServer {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
}

- (void)startSignalingIfReady {
    if (!_isTurnComplete) {
        return;
    }
    _state = kARDAppClientStateConnected;
    
    // Create peer connection
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
    RTCMediaStream *localStream = [self createLocalMediaStream];
    [_peerConnection addStream:localStream];
    if (_isInitiator) {
        [self sendOffer];
    } else {
        // TODO: not implemented yet
        //[self waitForAnswer];
    }
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    //if (self.defaultPeerConnectionConstraints) {
    //    return self.defaultPeerConnectionConstraints;
    //}
    NSArray *optionalConstraints = @[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]];
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                             optionalConstraints:optionalConstraints];
    return constraints;
}

- (void)sendOffer {
    [_peerConnection createOfferWithDelegate:self
                                 constraints:[self defaultOfferConstraints]];
}

// Offer/Answer Constraints
- (RTCMediaConstraints *)defaultOfferConstraints {
    // TODO: if we want to only work with audio, here's one place to update
    NSArray *mandatoryConstraints = @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaStream *)createLocalMediaStream
{
    RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];
    RTCVideoTrack* localVideoTrack = nil;
    
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
    // TODO(tkchin): local video capture for OSX. See
    // https://code.google.com/p/webrtc/issues/detail?id=3417.
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
    NSString *cameraID = nil;
    for (AVCaptureDevice *captureDevice in
         [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if (captureDevice.position == AVCaptureDevicePositionFront) {
            cameraID = [captureDevice localizedName];
            break;
        }
    }
    NSAssert(cameraID, @"Unable to get the front camera id");
    
    RTCVideoCapturer *capturer =
    [RTCVideoCapturer capturerWithDeviceName:cameraID];
    RTCMediaConstraints *mediaConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                  optionalConstraints:nil];
    RTCVideoSource *videoSource =
    [_factory videoSourceWithCapturer:capturer
                          constraints:mediaConstraints];
    localVideoTrack =
    [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
    if (localVideoTrack) {
        [localStream addVideoTrack:localVideoTrack];
    }
    // TODO: uncomment this after I setup MediaWebRTC protocol
    //[_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
#endif
    [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
    return localStream;
}

#pragma mark - Helpers
- (NSString*)updateSdpWithCandidates:(NSArray *)array
{
    // Candidates go after the 'a=rtcp' SDP attribute
    
    // Split the SDP in 2 parts: firstPart is up to the end of the 'a=rtcp' line
    // and the second part is from there to the end. Then insert the candidates
    // in-between
    
    // Since iOS doesn't support regex in NSStrings we need to find the place
    // to split by first searching for 'a=rtcp' and from that point to look
    // for the end of this line (i.e. \r\n)
    NSString *rtcpAttribute = @"a=rtcp:";
    NSRange startRange = [self.sdp rangeOfString:rtcpAttribute];
    NSString *fromRtcpAttribute = [self.sdp substringFromIndex:startRange.location];
    NSRange endRange = [fromRtcpAttribute rangeOfString:@"\r\n"];
    
    // Found the split point, break the sdp string in 2
    NSString *firstPart = [self.sdp substringToIndex:startRange.location + endRange.location + 2];
    NSString *lastPart = [self.sdp substringFromIndex:startRange.location + endRange.location + 2];
    NSMutableString * candidates = [[NSMutableString alloc] init];
    for (int i = 0; i < _iceCandidates.count; i++) {
        RTCICECandidate *iceCandidate = (RTCICECandidate*)[_iceCandidates objectAtIndex:i];
        if ([iceCandidate.sdpMid isEqualToString:@"audio"]) {
            // don't forget to prepend an 'a=' to make this an attribute line and to append '\r\n'
            [candidates appendFormat:@"a=%@\r\n",iceCandidate.sdp];
        }
    }
    NSString *updatedSdp = [NSString stringWithFormat:@"%@%@%@", firstPart, candidates, lastPart];
    
    // the complete message also has the sofia handle (so that sofia knows which active session to associate this with)
    NSString * completeMessage = [NSString stringWithFormat:@"%@ %@", self.sofia_handle, updatedSdp];
    //NSLog(@"Complete Message: %@", completeMessage);
    return completeMessage;
}



#pragma mark - RTCPeerConnectionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %d", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        
        if (stream.videoTracks.count) {
            // TODO: notify our delegate
            //RTCVideoTrack *videoTrack = stream.videoTracks[0];
            //[_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
    NSLog(@"ICE state changed: %d", newState);
    dispatch_async(dispatch_get_main_queue(), ^{
        // TODO: notify our delegate
        //[_delegate appClient:self didChangeConnectionState:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
    NSLog(@"ICE gathering state changed: %d", newState);
    if (newState == RTCICEGatheringComplete) {
        [self.mediaDelegate sdpReady:self withData:[self updateSdpWithCandidates:_iceCandidates]];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    NSLog(@"gotICECandidate");
    candidate.sdp;
    [_iceCandidates addObject:candidate];
    /*
    if ([_iceCandidates count] == 1) {
        [self.mediaDelegate sdpReady:self withData:[self updateSdpWithCandidates:_iceCandidates]];
    }
    */
    /*
    dispatch_async(dispatch_get_main_queue(), ^{
        //ARDICECandidateMessage *message = [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        //[self sendSignalingMessage:message];
        
    });
     */
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {
    NSLog(@"Opened data channel");
}

#pragma mark - RTCSessionDescriptionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
            /*
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            NSError *sdpError = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                           code:kARDAppClientErrorCreateSDP
                                                       userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
             */
            return;
        }
        [_peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sdp];

        // keep the SDP around; we'll be using it when all ICE candidates are downloaded
        self.sdp = sdp.description;
        /* We don't need to send the SDP here; we will be using Sofia SIP facilities for that
        ARDSessionDescriptionMessage *message =
        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
        [self sendSignalingMessage:message];
         */
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            //[self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =[[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                                          code:kARDAppClientErrorSetSDP
                                                      userInfo:userInfo];
            // TODO: notify our delegate
            //[_delegate appClient:self didError:sdpError];
            return;
        }
        
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!_isInitiator && !_peerConnection.localDescription) {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            [_peerConnection createAnswerWithDelegate:self
                                          constraints:constraints];
            
        }
    });
}


@end
