//
//  SipManager.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SipManagerDeviceDelegate;
@protocol SipManagerConnectionDelegate;

@interface SipManager : NSObject
- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate;
- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate andParams:(NSDictionary*)params;
// initialize Sofia, setup communication via pipe and enter event loop (notice that the event loop runs in a separate thread)
- (bool)eventLoop;
- (bool)register:(NSString*)registrar;
- (bool)message:(NSString*)msg to:(NSString*)recipient;
- (bool)invite:(NSString*)recipient;
- (bool)answer;
- (bool)decline;
- (bool)authenticate:(NSString*)string;
- (bool)cancel;
- (bool)bye;
- (bool)cli:(NSString*)cmd;
- (bool)updateParams:(NSDictionary*)params;

@property (weak) id<SipManagerDeviceDelegate> deviceDelegate;
@property (weak) id<SipManagerConnectionDelegate> connectionDelegate;
@property NSMutableDictionary* params;
@end

@protocol SipManagerDeviceDelegate <NSObject>
- (void)messageArrived:(SipManager *)sipManager withData:(NSString *)message;
// 'ringing' for incoming connections
- (void)callArrived:(SipManager *)sipManager;
@end

@protocol SipManagerConnectionDelegate <NSObject>
- (void)outgoingRinging:(SipManager *)sipManager;
- (void)outgoingEstablished:(SipManager *)sipManager;
//- (void)incomingRinging:(SipManager *)sipManager;
//- (void)incomingEstablished:(SipManager *)sipManager;
@end