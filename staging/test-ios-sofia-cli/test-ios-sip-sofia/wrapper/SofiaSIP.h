//
//  SofiaSIP.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ViewController.h"

//#include "ssc_oper.h"

@interface SofiaSIP : NSObject

- (id)initWithController:(ViewController*)viewController;
// initialize Sofia, setup communication via pipe and enter event loop (notice that the event loop runs in a separate thread)
- (bool)initialize;
- (bool)register:(NSString*)registrar;
- (bool)sendMessage:(NSString*)msg to:(NSString*)recepient;
- (bool)invite:(NSString*)recepient;
- (bool)answer;
- (bool)decline;
- (bool)authenticate:(NSString*)string;
- (bool)bye;

- (bool)generic:(NSString*)string;

@property ViewController* viewController;
//@property enum op_callstate_t callState;
@end

