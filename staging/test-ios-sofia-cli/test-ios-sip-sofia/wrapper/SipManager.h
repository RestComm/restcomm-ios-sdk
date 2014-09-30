//
//  SipManager.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SipManagerDelegate;

@interface SipManager : NSObject
- (id)init;
// initialize Sofia, setup communication via pipe and enter event loop (notice that the event loop runs in a separate thread)
- (bool)initialize;
- (bool)register:(NSString*)registrar;
- (bool)message:(NSString*)msg to:(NSString*)recipient;
- (bool)invite:(NSString*)recipient;
- (bool)answer;
- (bool)decline;
- (bool)authenticate:(NSString*)string;
- (bool)cancel;
- (bool)bye;
- (bool)cli:(NSString*)cmd;

@property (weak) id<SipManagerDelegate> delegate;
@end

@protocol SipManagerDelegate <NSObject>
- (void)messageArrived:(SipManager *)sipManager withData:(NSString *)msg;
- (void)callArrived:(SipManager *)sipManager;
@end