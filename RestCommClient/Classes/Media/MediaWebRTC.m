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

#import "WebRTC/RTCIceServer.h"
#import "WebRTC/RTCAVFoundationVideoSource.h"
#import "WebRTC/RTCAudioTrack.h"
#import "WebRTC/RTCIceCandidate.h"
#import "WebRTC/RTCPeerConnection.h"
#import "WebRTC/RTCIceServer.h"
#import "WebRTC/RTCMediaConstraints.h"
#import "WebRTC/RTCMediaStream.h"
#import "WebRTC/RTCConfiguration.h"
#import "WebRTC/RTCVideoTrack.h"
#import "WebRTC/RTCSessionDescription.h"
#import "WebRTC/RTCRtpSender.h"

#import "RestCommClient.h"

#import "common.h"
#import "RCUtilities.h"

@implementation MediaWebRTC

// TODO: update these properly
//static NSString *kARDTurnRequestUrl = @"https://computeengineondemand.appspot.com/turn?username=iapprtc&key=4080218913";
//static NSString *kARDTurnRequestUrl = @"https://service.xirsys.com/ice?ident=atsakiridis&secret=4e89a09e-bf6f-11e5-a15c-69ffdcc2b8a7&domain=cloud.restcomm.com&application=default&room=default&secure=1";
static NSString *kARDDefaultSTUNServerUrl = @"stun:stun.l.google.com:19302";
//static NSString *kARDDefaultSTUNServerUrl = @"stun:turn01.uswest.xirsys.com";
static NSString *kARDAppClientErrorDomain = @"ARDAppClient";
//static NSInteger kARDAppClientErrorUnknown = -1;
//static NSInteger kARDAppClientErrorRoomFull = -2;
//static NSInteger kARDAppClientErrorCreateSDP = -3;
//static NSInteger kARDAppClientErrorSetSDP = -4;
//static NSInteger kARDAppClientErrorInvalidClient = -5;
//static NSInteger kARDAppClientErrorInvalidRoom = -6;
static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


- (id)initWithDelegate:(id<MediaDelegate>)mediaDelegate parameters:(NSDictionary*)parameters
{
    RCLogNotice("[MediaWebRTC initWithDelegate]");
    self = [super init];
    if (self) {
        self.mediaDelegate = mediaDelegate;
        _isTurnComplete = NO;
        // for now we are always iniator
        _isInitiator = YES;
        self.sofia_handle = nil;
        self.videoAllowed = NO;
        _candidatesGathered = NO;
        _parameters = parameters;
    }
    return self;
}

- (void)dealloc {
    RCLogNotice("[MediaWebRTC dealloc]");
    //[self disconnect];
}

// entry point for WebRTC handling
// sofia handle is used for outgoing calls; nil in incoming
// sdp is used for incoming calls; nil in outgoing
- (void)connect:(NSString*)sofia_handle sdp:(NSString*)sdp isInitiator:(BOOL)initiator withVideo:(BOOL)videoAllowed
{
    RCLogNotice("[MediaWebRTC connect: %s \nsdp:%s \nisInitiator:%s \nwithVideo:%s]",
                [sofia_handle UTF8String],
                [sdp UTF8String],
                (initiator) ? "true" : "false",
                (videoAllowed) ? "true" : "false");
    if (!initiator) {
        _isInitiator = NO;
    }
    else {
        _isInitiator = YES;
    }
    self.videoAllowed = videoAllowed;
    if (sofia_handle) {
        self.sofia_handle = sofia_handle;
    }
    
    [self configure];

    if ([[_parameters objectForKey:@"turn-enabled"] boolValue]) {
        //NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
        /* Uncomment to use google's TURN servers (had issues with those by the way with huge delays)
        NSURL *turnRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?username=%@&key=%@",
                                                      [_parameters objectForKey:@"turn-url"],
                                                      [_parameters objectForKey:@"turn-username"],
                                                      [_parameters objectForKey:@"turn-password"]]];
         _turnClient = [[ARDCEODTURNClient alloc] initWithURL:turnRequestURL];
         */
        NSURL *turnRequestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?ident=%@&secret=%@&domain=%@&application=default&room=default&secure=1",
                                                      [_parameters objectForKey:@"turn-url"],
                                                      [_parameters objectForKey:@"turn-username"],
                                                      [_parameters objectForKey:@"turn-password"],
                                                      @"cloud.restcomm.com"]];

        
        _turnClient = [[XirsysTURNClient alloc] initWithURL:turnRequestURL];
        
        __weak MediaWebRTC *weakSelf = self;
        [_turnClient requestServersWithCompletionHandler:^(NSArray *turnServers,
                                                           NSError *error) {
            if (error) {
                RCLogError([error.localizedDescription UTF8String]);
                [self.mediaDelegate mediaController:self didError:error];
                return;
            }
            //NSArray * array = @[ [NSURL URLWithString:@""]];
            MediaWebRTC *strongSelf = weakSelf;
            // Need to remove the single object that we prepopulate manually which is the STUN server,
            // because with Xirsys the STUN server is returned in the list of TURN servers
            [strongSelf.iceServers removeAllObjects];
            [strongSelf.iceServers addObjectsFromArray:turnServers];
            strongSelf.isTurnComplete = YES;
            [strongSelf startSignalingIfReady:sdp];
        }];
    }
    else {
        self.isTurnComplete = YES;
        [self startSignalingIfReady:sdp];
    }
}

- (void)disconnect {
    RCLogNotice("[MediaWebRTC disconnect]");
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    
    _state = kARDAppClientStateDisconnected;

    /*
    if (self.hasJoinedRoomServerRoom) {
        [_roomServerClient leaveRoomWithRoomId:_roomId
                                      clientId:_clientId
                             completionHandler:nil];
    }
    
    if (_channel) {
        if (_channel.state == kARDSignalingChannelStateRegistered) {
            // Tell the other client we're hanging up.
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            [_channel sendMessage:byeMessage];
        }
        // Disconnect from collider.
        _channel = nil;
    }
    _clientId = nil;
    _roomId = nil;
     */
    _isInitiator = NO;
    //_hasReceivedSdp = NO;
    //_messageQueue = [NSMutableArray array];
    [_peerConnection close];
    _peerConnection = nil;
    _candidatesGathered = NO;
    RCLogNotice("[MediaWebRTC disconnect] end");
}


- (void) terminate
{
    RCLogNotice("[MediaWebRTC terminate]");
    //[RTCPeerConnectionFactory deinitializeSSL];
}

- (void)configure {
    _factory = [[RTCPeerConnectionFactory alloc] init];
    //_messageQueue = [NSMutableArray array]; 
    _iceCandidates = [NSMutableArray array];
    _iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
}

- (RTCIceServer *)defaultSTUNServer {
    //NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
    /*
    return [[RTCIceServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
     */
    return [[RTCIceServer alloc] initWithURLStrings:[NSArray arrayWithObject:kARDDefaultSTUNServerUrl]
                                    username:@""
                                    credential:@""];
}

- (void)startSignalingIfReady:(NSString*)sdp {
    if (!_isTurnComplete) {
        return;
    }
    _state = kARDAppClientStateConnected;
    
    // Create peer connection
    /*
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
     */
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    config.iceServers = _iceServers;
    _peerConnection = [_factory peerConnectionWithConfiguration:config
                                                    constraints:constraints
                                                       delegate:self];

    //RTCMediaStream *localStream = [self createLocalMediaStream];
    //[_peerConnection addStream:localStream];
    
    // Create AV senders.
    [self createAudioSender];
    [self createVideoSender];

    if (_isInitiator) {
        // Send offer
        __weak MediaWebRTC *weakSelf = self;
        [_peerConnection offerForConstraints:[self defaultOfferConstraints]
                           completionHandler:^(RTCSessionDescription *sdp,
                                               NSError *error) {
                               MediaWebRTC *strongSelf = weakSelf;
                               [strongSelf peerConnection:strongSelf.peerConnection
                              didCreateSessionDescription:sdp
                                                    error:error];
                           }];
        /*
        [_peerConnection createOfferWithDelegate:self
                                     constraints:[self defaultOfferConstraints]];
         */
    } else {
        [self processSignalingMessage:[sdp UTF8String] type:kARDSignalingMessageTypeOffer];
    }
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    /*
    NSArray *optionalConstraints = @[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]];
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                             optionalConstraints:optionalConstraints];
    return constraints;
     */
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc]
                                        initWithMandatoryConstraints:nil
                                        optionalConstraints:optionalConstraints];
    return constraints;
}

// Offer/Answer Constraints
- (RTCMediaConstraints *)defaultOfferConstraints {
    /*
    NSString * video = @"false";
    if (self.videoAllowed) {
        video = @"true";
    }
    
    NSArray *mandatoryConstraints = @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]];
     */
    
    // Although odd, removing mandatory constraints completely seems the cleanest way to do. That, because
    // if I leave offer to receive video, it seems to be triggering a video m-line to be added, which is bad
    // when we are making an audio call. Seems that webrtc makes best choices whether on when we are adding
    // a video media track to PeerConnection or not, and not based on these constraints which seem to be only
    // about the receiving end, and not the whole media channel. I'll leave it around just in case though, until this gets properly tested
    //NSArray *mandatoryConstraints = @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"]];
    
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    //NSString *valueLevelControl = _shouldUseLevelControl ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse;
    NSString *valueLevelControl = kRTCMediaConstraintsValueFalse;
    NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : valueLevelControl };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]  initWithMandatoryConstraints:mandatoryConstraints
                                           optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultMediaStreamConstraints {
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                             optionalConstraints:nil];
    return constraints;
}

/////
- (RTCRtpSender *)createVideoSender {
    RTCRtpSender *sender = nil;
    
    if (_videoAllowed) {
        sender = [_peerConnection senderWithKind:kRTCMediaStreamTrackKindVideo
                                        streamId:kARDMediaStreamId];
        RTCVideoTrack *track = [self createLocalVideoTrack];
        if (track) {
            sender.track = track;
            [self.mediaDelegate mediaController:self didReceiveLocalVideoTrack:track];
            //[_delegate appClient:self didReceiveLocalVideoTrack:track];
        }
    }
    return sender;
}

- (RTCRtpSender *)createAudioSender {
    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [_factory audioTrackWithSource:source
                                                  trackId:kARDAudioTrackId];
    RTCRtpSender *sender =
    [_peerConnection senderWithKind:kRTCMediaStreamTrackKindAudio
                           streamId:kARDMediaStreamId];
    sender.track = track;
    return sender;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
#if !TARGET_IPHONE_SIMULATOR
    if (_videoAllowed) {
        RTCMediaConstraints *mediaConstraints = [self defaultMediaStreamConstraints];
        RTCAVFoundationVideoSource *source = [_factory avFoundationVideoSourceWithConstraints:mediaConstraints];
        localVideoTrack = [_factory videoTrackWithSource:source
                                                 trackId:kARDVideoTrackId];
        [self.mediaDelegate mediaController:self didReceiveLocalVideoTrack:localVideoTrack];
    }
#endif
    return localVideoTrack;
}
/////

/*
- (RTCMediaStream *)createLocalMediaStream
{
    RCLogNotice("[MediaWebRTC createLocalMediaStream]");

    RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];

    if (self.videoAllowed) {
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
        
        [self.mediaDelegate mediaController:self didReceiveLocalVideoTrack:localVideoTrack];
#endif
    }
    [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
    
    return localStream;
}
 */

- (void)mute
{
    if (_peerConnection.senders) {
        for (int i = 0; i < [_peerConnection.senders count]; i++) {
            RTCMediaStreamTrack * track = [[_peerConnection.senders objectAtIndex:i] track];
            if ([track.kind isEqualToString:@"audio"]) {
                [track setIsEnabled:NO];
            }
        }
    }
}

- (void)unmute
{
    if (_peerConnection.senders) {
        for (int i = 0; i < [_peerConnection.senders count]; i++) {
            RTCMediaStreamTrack * track = [[_peerConnection.senders objectAtIndex:i] track];
            if ([track.kind isEqualToString:@"audio"]) {
                [track setIsEnabled:YES];
            }
        }
    }
}

- (void)muteVideo
{
    if (_peerConnection.senders) {
        for (int i = 0; i < [_peerConnection.senders count]; i++) {
            RTCMediaStreamTrack * track = [[_peerConnection.senders objectAtIndex:i] track];
            if ([track.kind isEqualToString:@"video"]) {
                [track setIsEnabled:NO];
            }
        }
    }
}

- (void)unmuteVideo
{
    if (_peerConnection.senders) {
        for (int i = 0; i < [_peerConnection.senders count]; i++) {
            RTCMediaStreamTrack * track = [[_peerConnection.senders objectAtIndex:i] track];
            if ([track.kind isEqualToString:@"video"]) {
                [track setIsEnabled:YES];
            }
        }
    }
}

#pragma mark - Helpers
// Not needed as we can access the full SDP (together with candidates) from PeerConnection.localDescription.description
// Let's keep it around in case we need it in the future, plus regex handling is good to have around
/*
// from candidateless sdp stored at self.sdp and candidates stored at array, we construct a full sdp
- (NSString*)outgoingUpdateSdpWithCandidates:(NSArray *)array
{
    // split audio & video candidates in 2 groups of strings
    NSMutableString * audioCandidates = [[NSMutableString alloc] init];
    NSMutableString * videoCandidates = [[NSMutableString alloc] init];
    BOOL isVideo = NO;
    for (int i = 0; i < _iceCandidates.count; i++) {
        RTCICECandidate *iceCandidate = (RTCICECandidate*)[_iceCandidates objectAtIndex:i];
        if ([iceCandidate.sdpMid isEqualToString:@"audio"]) {
            // don't forget to prepend an 'a=' to make this an attribute line and to append '\r\n'
            [audioCandidates appendFormat:@"a=%@\r\n",iceCandidate.sdp];
        }
        if ([iceCandidate.sdpMid isEqualToString:@"video"]) {
            // don't forget to prepend an 'a=' to make this an attribute line and to append '\r\n'
            [videoCandidates appendFormat:@"a=%@\r\n",iceCandidate.sdp];
            isVideo = YES;
        }
    }
    
    // insert inside the candidateless SDP the candidates per media type
    NSMutableString *searchedString = [self.sdp mutableCopy];
    NSRange searchedRange = NSMakeRange(0, [searchedString length]);
    NSString *pattern = @"a=rtcp:.*?\\r\\n";
    NSError  *error = nil;
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionDotMatchesLineSeparators
                                                                             error:&error];
    if (error != nil) {
        NSLog(@"outgoingUpdateSdpWithCandidates: regex error");
        return @"";
    }
    
    NSTextCheckingResult* match = [regex firstMatchInString:searchedString options:0 range:searchedRange];
    int matchIndex = 0;
    if (matchIndex == 0) {
        [regex replaceMatchesInString:searchedString options:0 range:[match range] withTemplate:[NSString stringWithFormat:@"%@%@",
                                                                                                             @"$0",audioCandidates]];
    }
    
    // search again since the searchedString has been altered
    NSArray* matches = [regex matchesInString:searchedString options:0 range:searchedRange];
    if ([matches count] == 2) {
        // count of 2 means we also have video. If we don't we shouldn't do anything
        NSTextCheckingResult* match = [matches objectAtIndex:1];
        [regex replaceMatchesInString:searchedString options:0 range:[match range] withTemplate:[NSString stringWithFormat:@"%@%@",
                                                                                                 @"$0", videoCandidates]];
    }
    
    // important: the complete message also has the sofia handle (so that sofia knows which active session to associate this with)
    NSString * completeMessage = [NSString stringWithFormat:@"%@", searchedString];

    return completeMessage;
}
 */

// remove candidate lines from the given sdp and return them as elements of an NSArray
-(NSDictionary*)incomingFilterCandidatesFromSdp:(NSMutableString*)sdp
{
    NSMutableArray * audioCandidates = [[NSMutableArray alloc] init];
    NSMutableArray * videoCandidates = [[NSMutableArray alloc] init];
    
    NSString *searchedString = sdp;
    NSRange searchedRange = NSMakeRange(0, [searchedString length]);
    NSString *pattern = @"m=audio|m=video|a=(candidate.*)\\r\\n";
    NSError  *error = nil;
    
    NSString * collectionState = @"none";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:searchedString options:0 range: searchedRange];
    for (NSTextCheckingResult* match in matches) {
        //NSString* matchText = [searchedString substringWithRange:[match range]];
        NSString * stringMatch = [searchedString substringWithRange:[match range]];
        if ([stringMatch isEqualToString:@"m=audio"]) {
            // enter audio collection state
            collectionState = @"audio";
            continue;
        }
        if ([stringMatch isEqualToString:@"m=video"]) {
            // enter audio video collection state
            collectionState = @"audio";
            continue;
        }
        
        if ([collectionState isEqualToString:@"audio"]) {
            [audioCandidates addObject:[searchedString substringWithRange:[match rangeAtIndex:1]]];
        }
        if ([collectionState isEqualToString:@"video"]) {
            [videoCandidates addObject:[searchedString substringWithRange:[match rangeAtIndex:1]]];
        }
    }

    NSString *removePattern = @"a=(candidate.*)\\r\\n";
    NSRegularExpression* removeRegex = [NSRegularExpression regularExpressionWithPattern:removePattern options:0 error:&error];
    // remove the candidates (we want a candidateless SDP)
    [removeRegex replaceMatchesInString:sdp options:0 range:NSMakeRange(0, [sdp length]) withTemplate:@""];

    return [NSDictionary dictionaryWithObjectsAndKeys:audioCandidates, @"audio",
            videoCandidates, @"video", nil];
}

// TODO: remove when ready
// temporary: until the MMS issue is fixed, try to workaround it by appending the missing part
- (void)workaroundTruncation:(NSMutableString*)sdp
{
    NSString *pattern = @"cnam$";
    NSError  *error = nil;

    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    [regex replaceMatchesInString:sdp options:0 range:NSMakeRange(0, [sdp length]) withTemplate:@"$0e:r5NeEmW7rYyFBr5w"];
}

- (void)processSignalingMessage:(const char *)message type:(int)type
{
    NSParameterAssert(_peerConnection);
    
    RTCSdpType sdpType;
    if (type == kARDSignalingMessageTypeOffer) {
        sdpType = RTCSdpTypeOffer;
    }
    else if (type == kARDSignalingMessageTypeAnswer) {
        sdpType = RTCSdpTypeAnswer;
    }
    else {
        return;
    }
    
    // 'type' is @"offer" (we are not the initiator) or @"answer" (we are the initiator) and 'sdp' is the regular SDP
    NSMutableString * msg = [NSMutableString stringWithUTF8String:message];
    [self workaroundTruncation:msg];
    NSDictionary * candidates = [self incomingFilterCandidatesFromSdp:msg];
    RTCSessionDescription *description = [[RTCSessionDescription alloc] initWithType:sdpType
                                                                                 sdp:msg];
    
    // Prefer H264 if available.
    RTCSessionDescription *sdpPreferringH264 =
    [MediaWebRTC descriptionForDescription:description
                       preferredVideoCodec:@"H264"];
    
    __weak MediaWebRTC *weakSelf = self;
    [_peerConnection setRemoteDescription:sdpPreferringH264
                        completionHandler:^(NSError *error) {
                            MediaWebRTC *strongSelf = weakSelf;
                            [strongSelf peerConnection:strongSelf.peerConnection
                     didSetSessionDescriptionWithError:error];
                        }];
    
    //[_peerConnection setRemoteDescriptionWithDelegate:self
    //                               sessionDescription:description];
    for (NSString * key in candidates) {
        for (NSString * candidate in [candidates objectForKey:key]) {
            // remember that we have set 'key' to be either 'audio' or 'video' inside incomingFilterCandidatesFromSdp
            RTCIceCandidate *iceCandidate = [[RTCIceCandidate alloc] initWithSdp:candidate
                                                                   sdpMLineIndex:0
                                                                          sdpMid:key];
            [_peerConnection addIceCandidate:iceCandidate];
        }
    }

    /*
    switch (type) {
        case kARDSignalingMessageTypeOffer: {
            // 'type' is @"offer" (we are not the initiator) or @"answer" (we are the initiator) and 'sdp' is the regular SDP
            NSMutableString * msg = [NSMutableString stringWithUTF8String:message];
            //[self workaroundTruncation:msg];
            NSDictionary * candidates = [self incomingFilterCandidatesFromSdp:msg];
            RTCSessionDescription *description = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer
                                                                                         sdp:msg];
            
            // Prefer H264 if available.
            RTCSessionDescription *sdpPreferringH264 =
            [MediaWebRTC descriptionForDescription:description
                               preferredVideoCodec:@"H264"];

            __weak MediaWebRTC *weakSelf = self;
            [_peerConnection setRemoteDescription:sdpPreferringH264
                                completionHandler:^(NSError *error) {
                                    MediaWebRTC *strongSelf = weakSelf;
                                    [strongSelf peerConnection:strongSelf.peerConnection
                             didSetSessionDescriptionWithError:error];
                                }];
            
            //[_peerConnection setRemoteDescriptionWithDelegate:self
            //                               sessionDescription:description];
            for (NSString * key in candidates) {
                for (NSString * candidate in [candidates objectForKey:key]) {
                    // remember that we have set 'key' to be either 'audio' or 'video' inside incomingFilterCandidatesFromSdp
                    RTCIceCandidate *iceCandidate = [[RTCIceCandidate alloc] initWithSdp:candidate
                                                                           sdpMLineIndex:0
                                                                                  sdpMid:key];
                    [_peerConnection addIceCandidate:iceCandidate];
                }
            }
            
            break;

        }
        case kARDSignalingMessageTypeAnswer: {
            // 'type' is @"offer" (we are not the initiator) or @"answer" (we are the initiator) and 'sdp' is the regular SDP
            NSMutableString * msg = [NSMutableString stringWithUTF8String:message];
            [self workaroundTruncation:msg];
            NSDictionary * candidates = [self incomingFilterCandidatesFromSdp:msg];
            RTCSessionDescription *description = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer
                                                                                         sdp:msg];
            [_peerConnection setRemoteDescriptionWithDelegate:self
                                           sessionDescription:description];
            
            for (NSString * key in candidates) {
                for (NSString * candidate in [candidates objectForKey:key]) {
                    RTCIceCandidate *iceCandidate = [[RTCIceCandidate alloc] initWithSdp:candidate
                                                                           sdpMLineIndex:0
                                                                                  sdpMid:key];
                    [_peerConnection addICECandidate:iceCandidate];
                }
            }
            
            break;
        }
    }
     */
}

#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC signalingStateChanged:%d]", stateChanged);
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC addedStream] Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [self.mediaDelegate mediaController:self didReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC removedStream]");
    });
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC peerConnectionOnRenegotiationNeeded]");
        //NSLog(@"WARNING: Renegotiation needed but unimplemented.");
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC iceConnectionChanged:%d]", newState);
        if (newState == RTCIceConnectionStateDisconnected) {
            RCLogError("[MediaWebRTC iceConnectionChanged] transitioned to RTCIceConnectionStateDisconnected");
        }
        /*
        if (newState == RTCIceConnectionStateFailed || newState == RTCIceConnectionStateDisconnected) {
            NSString * errorMsg;
            if (newState == RTCIceConnectionStateFailed) {
                errorMsg = @"iceConnectionChanged: ICE connection failed";
            }
            else {
                errorMsg = @"iceConnectionChanged: ICE connection disconnected";
            }
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: errorMsg,
                                       };
            NSError *iceError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                           code:ERROR_WEBRTC_ICE
                                                       userInfo:userInfo];
            RCLogError("[MediaWebRTC iceConnectionChanged] %s", [[RCUtilities stringifyDictionary:userInfo] UTF8String]);
            [self.mediaDelegate mediaController:self didError:iceError];
        }
         */
        if (newState == RTCIceConnectionStateFailed) {
            NSString * errorMsg;
            errorMsg = @"iceConnectionChanged: ICE connection failed";
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: errorMsg,
                                       };
            NSError *iceError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                           code:ERROR_WEBRTC_ICE
                                                       userInfo:userInfo];
            RCLogError("[MediaWebRTC iceConnectionChanged] %s", [[RCUtilities stringifyDictionary:userInfo] UTF8String]);
            [self.mediaDelegate mediaController:self didError:iceError];
        }

        if (newState == RTCIceConnectionStateConnected) {
            [self.mediaDelegate mediaController:self didIceConnectAsInitiator:_isInitiator];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC iceGatheringChanged:%d]", newState);
        
        if (newState == RTCIceGatheringStateComplete) {
            if ([_iceCandidates count] > 0) {
                RCLogNotice("[MediaWebRTC iceGatheringChanged:], state Complete");
                [self candidateGatheringComplete];
            }
            else {
                RCLogError("[MediaWebRTC iceGatheringChanged:], state Complete but no candidates collected");
                
                NSError *iceError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                               code:ERROR_WEBRTC_ICE
                                                           userInfo:@{ NSLocalizedDescriptionKey: @"ICEGatheringState 'complete' but no candidates collected" }];
                [self.mediaDelegate mediaController:self didError:iceError];
            }
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC gotICECandidate:%s]", [[candidate sdp] UTF8String]);
        [_iceCandidates addObject:candidate];
        
        // NOTE: when first candidate is retrieved, start timer. If the candidates haven't been all retrieved in 'timeout' seconds, then
        // we need to stop waiting for 'candidates gathered' event and send SDP to the peer right then. Reason for that is that in iOS
        // and when TURN is enabled, in order for 'candidates gathered' event to fire, we first need to get the SDP answer's
        // candidates (when we are initiator) from the peer and that will never happen unless we first send the SDP offer.
        if ([_iceCandidates count] == 1) {
            
            /*
            // default is 5 seconds
            float timeout = 5.0;
            if ([_parameters objectForKey:@"turn-candidate-timeout"]) {
                timeout = [[_parameters objectForKey:@"turn-candidate-timeout"] floatValue];
            }
            [self performSelector:@selector(candidateGatheringComplete) withObject:nil afterDelay:timeout];
             */
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates
{
    RCLogNotice("[MediaWebRTC didRemoveIceCandidates:] Not Implemented");
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC didOpenDataChannel]");
    });
}

#pragma mark - RTCSessionDescriptionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC didCreateSessionDescription]");
        if (error) {
            RCLogError("[MediaWebRTC didCreateSessionDescription] Failed to create session description. Error: %s", [[RCUtilities stringifyDictionary:[error userInfo]] UTF8String]);
            [self disconnect];

            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"didCreateSessionDescription: Failed to create session description",
                                       };
            NSError *sdpError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                           code:ERROR_WEBRTC_SDP
                                                       userInfo:userInfo];
            [self.mediaDelegate mediaController:self didError:sdpError];
            return;
        }
        
        //RCLogDebug("[MediaWebRTC didCreateSessionDescription], sdp: %s", [sdp.description UTF8String]);
        //[_peerConnection setLocalDescriptionWithDelegate:self
        //                              sessionDescription:sdp];
        // Prefer H264 if available.
        RTCSessionDescription *sdpPreferringH264 =
        [MediaWebRTC descriptionForDescription:sdp
                           preferredVideoCodec:@"H264"];
        __weak MediaWebRTC *weakSelf = self;
        [_peerConnection setLocalDescription:sdpPreferringH264
                           completionHandler:^(NSError *error) {
                               MediaWebRTC *strongSelf = weakSelf;
                               [strongSelf peerConnection:strongSelf.peerConnection
                        didSetSessionDescriptionWithError:error];
                           }];


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
        RCLogNotice("[MediaWebRTC didSetSessionDescriptionWithError]");
        if (error) {
            RCLogError("[MediaWebRTC didSetSessionDescriptionWithError] Failed to set session description. Error: %s", [[RCUtilities stringifyDictionary:[error userInfo]] UTF8String]);

            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"didSetSessionDescriptionWithError: Failed to set session description",
                                       };
            NSError *sdpError =[[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                          code:ERROR_WEBRTC_SDP
                                                      userInfo:userInfo];

            [self.mediaDelegate mediaController:self didError:sdpError];
            return;
        }
        
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!_isInitiator && !_peerConnection.localDescription) {
            //RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            //[_peerConnection createAnswerWithDelegate:self
            //                              constraints:constraints];
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            __weak MediaWebRTC *weakSelf = self;
            [_peerConnection answerForConstraints:constraints
                                completionHandler:^(RTCSessionDescription *sdp,
                                                    NSError *error) {
                                    MediaWebRTC *strongSelf = weakSelf;
                                    [strongSelf peerConnection:strongSelf.peerConnection
                                   didCreateSessionDescription:sdp
                                                         error:error];
                                }];

        }
    });
}

- (void)candidateGatheringComplete
{
    if (!_candidatesGathered) {
        RCLogNotice("[MediaWebRTC candidateGatheringComplete] notifying signaling to send SDP");
        _candidatesGathered = YES;
        //[self.mediaDelegate mediaController:self didCreateSdp:[self outgoingUpdateSdpWithCandidates:_iceCandidates] isInitiator:_isInitiator];
        [self.mediaDelegate mediaController:self didCreateSdp:_peerConnection.localDescription.sdp isInitiator:_isInitiator];
    }
    else {
        RCLogNotice("[MediaWebRTC candidateGatheringComplete] already notified signaling; skipping");
    }
}

+ (RTCSessionDescription *)descriptionForDescription:(RTCSessionDescription *)description
                                 preferredVideoCodec:(NSString *)codec
{
    NSString *sdpString = description.sdp;
    NSString *lineSeparator = @"\n";
    NSString *mLineSeparator = @" ";
    // Copied from PeerConnectionClient.java.
    // TODO(tkchin): Move this to a shared C++ file.
    NSMutableArray *lines =
    [NSMutableArray arrayWithArray:
     [sdpString componentsSeparatedByString:lineSeparator]];
    NSInteger mLineIndex = -1;
    NSString *codecRtpMap = nil;
    // a=rtpmap:<payload type> <encoding name>/<clock rate>
    // [/<encoding parameters>]
    NSString *pattern =
    [NSString stringWithFormat:@"^a=rtpmap:(\\d+) %@(/\\d+)+[\r]?$", codec];
    NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:pattern
                                              options:0
                                                error:nil];
    for (NSInteger i = 0; (i < lines.count) && (mLineIndex == -1 || !codecRtpMap);
         ++i) {
        NSString *line = lines[i];
        if ([line hasPrefix:@"m=video"]) {
            mLineIndex = i;
            continue;
        }
        NSTextCheckingResult *codecMatches =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, line.length)];
        if (codecMatches) {
            codecRtpMap =
            [line substringWithRange:[codecMatches rangeAtIndex:1]];
            continue;
        }
    }
    if (mLineIndex == -1) {
        //RTCLog(@"No m=video line, so can't prefer %@", codec);
        return description;
    }
    if (!codecRtpMap) {
        //RTCLog(@"No rtpmap for %@", codec);
        return description;
    }
    NSArray *origMLineParts =
    [lines[mLineIndex] componentsSeparatedByString:mLineSeparator];
    if (origMLineParts.count > 3) {
        NSMutableArray *newMLineParts =
        [NSMutableArray arrayWithCapacity:origMLineParts.count];
        NSInteger origPartIndex = 0;
        // Format is: m=<media> <port> <proto> <fmt> ...
        [newMLineParts addObject:origMLineParts[origPartIndex++]];
        [newMLineParts addObject:origMLineParts[origPartIndex++]];
        [newMLineParts addObject:origMLineParts[origPartIndex++]];
        [newMLineParts addObject:codecRtpMap];
        for (; origPartIndex < origMLineParts.count; ++origPartIndex) {
            if (![codecRtpMap isEqualToString:origMLineParts[origPartIndex]]) {
                [newMLineParts addObject:origMLineParts[origPartIndex]];
            }
        }
        NSString *newMLine =
        [newMLineParts componentsJoinedByString:mLineSeparator];
        [lines replaceObjectAtIndex:mLineIndex
                         withObject:newMLine];
    } else {
        //RTCLogWarning(@"Wrong SDP media description format: %@", lines[mLineIndex]);
    }
    NSString *mangledSdpString = [lines componentsJoinedByString:lineSeparator];
    return [[RTCSessionDescription alloc] initWithType:description.type
                                                   sdp:mangledSdpString];
}

@end
