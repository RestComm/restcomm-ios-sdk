//
//  RCCallKitProvider.h
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 10/17/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CallKit/CXCall.h>
#import <CallKit/CallKit.h>
#import "RestCommClient.h"

@protocol RCCallKitProviderDelegate
/**
 *  @abstract newIncomingCall is called when call needs to be handled by the app
 *  (when the app is not in inactive mode)
 *  @param connection The RCConnection instance
 */
- (void)newIncomingCall:(RCConnection *)connection;

/*
 *  Will be called when call is Ended from Callkit (locked phone mode)
 */
- (void)callEnded;
@end

@interface RCCallKitProvider : NSObject <CXProviderDelegate, RCConnectionDelegate>

@property (nonatomic, strong) RCConnection * connection;
@property (nonatomic, strong) NSUUID *currentUdid;

- (id)initWithDelegate:(id<RCCallKitProviderDelegate>)delegate;

- (void)initRCConnection:(RCConnection *)connection;

- (void)answerWithCallKit;

//Important, we will refactor in the future

- (void)reportConnecting;

- (void)reportConnected;

- (void)performStartCall:(NSString *)handle;

- (void)performAnswerCall;

- (void)performEndCallAction;


@end
