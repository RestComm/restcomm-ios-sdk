//
//  MediaWebRTC.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 2/10/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCPeerConnectionFactory.h"
#import "ARDCEODTURNClient.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCSessionDescriptionDelegate.h"

@protocol MediaDelegate;

typedef NS_ENUM(NSInteger, ARDAppClientState) {
    // Disconnected from servers.
    kARDAppClientStateDisconnected,
    // Connecting to servers.
    kARDAppClientStateConnecting,
    // Connected to servers.
    kARDAppClientStateConnected,
};

@interface MediaWebRTC : NSObject  //<RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
- (id)initWithDelegate:(id<MediaDelegate>)mediaDelegate;

/*
@property RTCPeerConnectionFactory * factory;
@property RTCPeerConnection * peerConnection;
@property NSMutableArray * messageQueue;
@property NSMutableArray * iceServers;
@property ARDCEODTURNClient * turnClient;
@property BOOL isTurnComplete;
@property BOOL isInitiator;
@property ARDAppClientState state;
 */
// our delegate is SIP Manager
@property (weak) id<MediaDelegate> mediaDelegate;
@property(nonatomic, readonly) ARDAppClientState state;

@end

@protocol MediaDelegate <NSObject>
// when WebRTC module knows the SDP string it needs to communicate it to its delegate (i.e. SIP Manager) who in turn will notify SIP sofia
- (void)sdpReady:(MediaWebRTC *)media withData:(NSString *)sdpString;
@end