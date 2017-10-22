//
//  RCCallKitProvider.m
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 10/17/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import "RCCallKitProvider.h"

@interface RCCallKitProvider()
@property (nonatomic, strong) CXCallController *callKitCallController;
@property (nonatomic, assign) id<RCCallKitProviderDelegate> delegate;
@property (nonatomic, strong) CXProvider *callKitProvider;
@end

@implementation RCCallKitProvider

- (id)initWithDelegate:(id<RCCallKitProviderDelegate>)delegate{
    self = [super init];
    if (self){
        NSLog(@"Configuring CallKit");
        CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Resctomm"];
        configuration.maximumCallGroups = 1;
        configuration.maximumCallsPerCallGroup = 1;
        configuration.supportedHandleTypes = [NSSet setWithObjects:[NSNumber numberWithInteger:CXHandleTypeGeneric],[NSNumber numberWithInteger:CXHandleTypePhoneNumber], nil];
        UIImage *callkitIcon = [UIImage imageNamed:@"restcomm-logo-call-139x58.png"];
        configuration.iconTemplateImageData = UIImagePNGRepresentation(callkitIcon);
        self.delegate = delegate;
        
        self.callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
        [self.callKitProvider setDelegate:self queue:nil];
        
        self.callKitCallController = [[CXCallController alloc] init];
    }
    return self;
}


- (void)initRCConnection:(RCConnection *)connection{
    self.connection = connection;
    self.connection.delegate = self;
}

#pragma mark - CXProvider callback methods

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action{
    NSLog(@"CXProvider performEndCallAction");
    //[self performEndCallActionWithUUID:self.currentUdid];
    [self.delegate callEnded];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action{
    NSLog(@"CXProvider performSetHeldCallAction");
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action{
    NSLog(@"CXProvider performSetMutedCallAction");
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action{
    NSLog(@"CXProvider performSetGroupCallAction");
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action{
    NSLog(@"CXProvider performPlayDTMFCallAction");
    [action fulfill];
}
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action{
    NSLog(@"CXProvider performAnswerCallAction");
    
    //there is no way to know is the device locked or not.
    [self.delegate newIncomingCallAnswered:self.connection];
    
    [action fulfill];
}

- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID connectedAtDate:(nullable NSDate *)dateConnected{
    NSLog(@"Ognjne");
}

//-(BOOL)application:(UIApplication *)application continueUserActivity:(nonnull NSUserActivity *)userActivity restorationHandler:(nonnull void (^)(NSArray * _Nullable))restorationHandler{
//    NSString *a = @"";
//    return NO;
//}

- (void)providerDidReset:(CXProvider *)provider{
    NSLog(@"CXProvider providerDidReset");
    if (self.connection){
        self.currentUdid = nil;
        [self.connection disconnect];//?oggie review
    }
}

#pragma mark - RCConnection delegate

- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error{
    NSLog(@"CallKit connection:(RCConnection*)connection didFailWithError ===> Error: %@", error);
    [self performEndCallAction];
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
    [self performEndCallAction];
}

- (void)connectionDidGetDeclined:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidGetDeclined:(RCConnection*)connection");
    [self performEndCallAction];
    [self.connection disconnect];
    self.connection = nil;
}

- (void)connectionDidDisconnect:(RCConnection*)connection{
    NSLog(@"CallKit connectionDidDisconnect:(RCConnection*)connection");
    [self performEndCallAction];
    [self.connection disconnect];
    self.connection = nil;
}

- (void)connection:(RCConnection *)connection didReceiveLocalVideo:(RTCVideoTrack *)localVideoTrack{
    
}

- (void)connection:(RCConnection *)connection didReceiveRemoteVideo:(RTCVideoTrack *)remoteVideoTrack{
    
}

#pragma mark Provider methods
- (void)reportIncomingCallFrom:(NSString *) from {
    NSLog(@"CallKit reportIncomingCallFrom with UUID %@", self.currentUdid);
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:from];
    
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = callHandle;
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.hasVideo = NO;
    
    [self.callKitProvider reportNewIncomingCallWithUUID:self.currentUdid update:callUpdate completion:^(NSError *error) {
        if (!error) {
            NSLog(@"CallKit Incoming call successfully reported. UUID: %@", self.currentUdid);
        } else {
            NSLog(@"Failed to report incoming call successfully; uuid: %@ error: %@.", self.currentUdid, [error localizedDescription]);
            self.currentUdid = nil;
        }
    }];
}


#warning not implemented yet  Ogi
- (void)performStartCall:(NSString *)handle {
    
    NSLog(@"CallKit performStartCallActionWithUUID with UUID %@", self.currentUdid);
    if (self.currentUdid == nil || handle == nil) {
        return;
    }
    
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:handle];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:self.currentUdid handle:callHandle];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"CallKit StartCallAction transaction request failed: %@", [error localizedDescription]);
            [startCallAction fail];
        } else {
            NSLog(@"CallKit StartCallAction transaction request successful");
            
            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = NO;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO; //Ogi, need to get from connection
            
            [self.callKitProvider reportCallWithUUID:self.currentUdid updated:callUpdate];
            [startCallAction fulfillWithDateStarted:[NSDate date]];
        }
    }];
}

- (void)performEndCallAction{
    NSLog(@"CallKit performEndCallAction UDID: %@", self.currentUdid);
    
    if (self.currentUdid == nil) {
        return;
    }
    
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:self.currentUdid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        self.currentUdid = nil;
        if (error) {
            NSLog(@"CallKit EndCallAction transaction request failed for UUID: %@ and error: %@", self.currentUdid, [error localizedDescription]);
            [endCallAction fail];
        }
        else {
            NSLog(@"CallKit EndCallAction transaction request successful for UUID: %@", self.currentUdid);
            [endCallAction fulfillWithDateEnded:[NSDate date]];
            
        }
    }];
}

- (void)reportConnecting{
     [self.callKitProvider reportOutgoingCallWithUUID:self.currentUdid startedConnectingAtDate: [NSDate date]];
}

- (void)reportConnected{
    [self.callKitProvider reportOutgoingCallWithUUID:self.currentUdid connectedAtDate:[NSDate date]];
}

- (void)answerWithCallKit{
    self.connection.delegate = self;
    self.currentUdid = [NSUUID UUID];
    NSLog(@"CallKit Current udid %@", self.currentUdid);
    [self reportIncomingCallFrom:[self.connection.parameters objectForKey:@"from"]];
}



@end
