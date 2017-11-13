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

#import "RCCallKitProvider.h"
#import "AVFoundation/AVFoundation.h"

@interface RCCallKitProvider()
@property (nonatomic, strong) CXCallController *callKitCallController;
@property (nonatomic, assign) id<RCCallKitProviderDelegate> delegate;
@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) NSUUID *currentUUID;
@end

@implementation RCCallKitProvider

- (id)initWithDelegate:(id<RCCallKitProviderDelegate>)delegate andImage:(NSString *)imageName{
    self = [super init];
    if (self){
        NSLog(@"Configuring CallKit");
        CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Restcomm"];
        configuration.maximumCallGroups = 1;
        configuration.maximumCallsPerCallGroup = 1;
        configuration.supportsVideo = YES;
        configuration.supportedHandleTypes = [NSSet setWithObjects:[NSNumber numberWithInteger:CXHandleTypeGeneric],[NSNumber numberWithInteger:CXHandleTypePhoneNumber], nil];
       
        UIImage *callkitIcon = [UIImage imageNamed:imageName];
        configuration.iconTemplateImageData = UIImagePNGRepresentation(callkitIcon);
        
        self.callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
        [self.callKitProvider setDelegate:self queue:nil];
        self.delegate = delegate;
        self.callKitCallController = [[CXCallController alloc] init];
    }
    return self;
}


#pragma mark - CXProvider callback methods

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action{
    NSLog(@"CXProvider performEndCallAction");
    [self.delegate callEnded];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action{
    NSLog(@"CXProvider performSetHeldCallAction");
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action{
    NSLog(@"CXProvider performSetMutedCallAction");
    [self.connection setMuted:action.muted];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action{
    NSLog(@"CXProvider performSetGroupCallAction");
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action{
    NSLog(@"CXProvider performPlayDTMFCallAction");
    [self.connection sendDigits:action.digits];
    NSLog(@"%@", action.digits);
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSLog(@"CXProvider performPlayDTMFCallAction");
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action{
    NSLog(@"CXProvider performAnswerCallAction");
    
    //there is no way to know is the device locked or not.
    [self.delegate newIncomingCallAnswered:self.connection ];
    [self routeAudioToSpeaker];
    [action fulfill];
}

- (void)providerDidReset:(CXProvider *)provider{
    NSLog(@"CXProvider providerDidReset");
    if (self.connection){
        self.currentUUID = nil;
        [self.connection disconnect];
    }
}

#pragma mark - RCConnection delegate

- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error{
    NSLog(@"CallKit connection:(RCConnection*)connection didFailWithError ===> Error: %@", error);
    [self endCall];
    self.connection = nil;
}

- (void)connectionDidStartConnecting:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidStartConnecting:(RCConnection*)connection");
    [self reportConnecting];
}

- (void)connectionDidConnect:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidConnect:(RCConnection*)connection");
    [self reportConnected];
}

- (void)connectionDidCancel:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidCancel:(RCConnection*)connection");
    [self endCall];
}

- (void)connectionDidGetDeclined:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidGetDeclined:(RCConnection*)connection");
    [self endCall];
    [self.connection disconnect];
    self.connection = nil;
}

- (void)connectionDidDisconnect:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidDisconnect:(RCConnection*)connection");
    [self endCall];
    [self.connection disconnect];
    self.connection = nil;
}

- (void)connection:(RCConnection *)connection didReceiveLocalVideo:(RTCVideoTrack *)localVideoTrack{
    //do nothing
}

- (void)connection:(RCConnection *)connection didReceiveRemoteVideo:(RTCVideoTrack *)remoteVideoTrack{
    //do nothing
}


#pragma mark Provider methods

- (void)startCall:(NSString *)handle isVideo:(BOOL)isVideo{
    //start call only if we dont have one already
    //started
    if (!self.currentUUID){
        self.currentUUID = [NSUUID UUID];
        NSLog(@"CallKit performStartCallActionWithUUID with UUID %@", self.currentUUID);
        if (!handle) {
            return;
        }
        
        CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:handle];
        CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:self.currentUUID handle:callHandle];
        startCallAction.video = isVideo;
        
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
        
        [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
            if (error) {
                NSLog(@"CallKit StartCallAction transaction request failed: %@", [error localizedDescription]);
                [startCallAction fail];
            } else {
                NSLog(@"CallKit StartCallAction transaction request successful");
                [startCallAction fulfillWithDateStarted:[NSDate date]];
            }
        }];
    }
}


- (void)reportIncomingCallFrom:(NSString *) from hasVideo:(BOOL)hasVideo {
    NSLog(@"CallKit reportIncomingCallFrom with UUID %@", self.currentUUID);
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:from];
    
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = callHandle;
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;

    callUpdate.hasVideo = hasVideo;
    
    [self.callKitProvider reportNewIncomingCallWithUUID:self.currentUUID update:callUpdate completion:^(NSError *error) {
        if (!error) {
            NSLog(@"CallKit Incoming call successfully reported. UUID: %@", self.currentUUID);
        } else {
            NSLog(@"Failed to report incoming call successfully; uuid: %@ error: %@.", self.currentUUID, [error localizedDescription]);
            self.currentUUID = nil;
        }
    }];
}

- (void)endCall{
    NSLog(@"CallKit performEndCallAction UDID: %@", self.currentUUID);
    
    if (self.currentUUID == nil) {
        return;
    }
    
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:self.currentUUID];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"CallKit EndCallAction transaction request failed for UUID: %@ and error: %@", self.currentUUID, [error localizedDescription]);
            [endCallAction fail];
        }
        else {
            NSLog(@"CallKit EndCallAction transaction request successful for UUID: %@", self.currentUUID);
        }
        self.currentUUID = nil;
    }];
}

- (void)reportConnecting{
     [self.callKitProvider reportOutgoingCallWithUUID:self.currentUUID startedConnectingAtDate: [NSDate date]];
}

- (void)reportConnected{
    [self.callKitProvider reportOutgoingCallWithUUID:self.currentUUID connectedAtDate:[NSDate date]];
}

- (void)presentIncomingCallWithVideo:(BOOL)isVideo{
    self.connection.delegate = self;
    self.currentUUID = [NSUUID UUID];
    NSLog(@"CallKit Current udid %@", self.currentUUID);
    [self reportIncomingCallFrom:[self.connection.parameters objectForKey:@"from"] hasVideo:isVideo];
}

- (void)routeAudioToSpeaker {
    NSError *error = nil;
    //https://developer.apple.com/documentation/avfoundation/avaudiosessioncategoryplayandrecord
    //we need to set category
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                 mode:AVAudioSessionModeVoiceChat
                                              options:(AVAudioSessionCategoryOptionDefaultToSpeaker) error:&error]) {
        NSLog(@"Unable to reroute audio: %@", [error localizedDescription]);
    }
}




@end
