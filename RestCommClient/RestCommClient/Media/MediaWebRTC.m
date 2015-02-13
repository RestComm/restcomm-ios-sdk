//
//  MediaWebRTC.m
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 2/10/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "ARDAppClient+Internal.h"
#import "MediaWebRTC.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "RTCPeerConnection.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"

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

        [self main];
    }
    return self;
}

// entry point for WebRTC handling
- (void) main
{
    [RTCPeerConnectionFactory initializeSSL];
    
    // TODO: probably need to adapt & use those
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
    _messageQueue = [NSMutableArray array];
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
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]
                                     ];
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc]
                                        initWithMandatoryConstraints:nil
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
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
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
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        /*
        ARDICECandidateMessage *message =
        [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        [self sendSignalingMessage:message];
         */
    });
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
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
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
