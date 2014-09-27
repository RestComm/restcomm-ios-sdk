//
//  SofiaSIP.h
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SofiaSIP : NSObject

- (id)init;
// initialize Sofia, setup communication via pipe and enter event loop (notice that the event loop runs in a separate thread)
- (bool)initialize;
- (bool)register:(NSString*)registrar;
- (bool)sendMessage:(NSString*)msg to:(NSString*)recepient;
- (bool)invite:(NSString*)recepient;
- (bool)authenticate:(NSString*)string;
- (bool)bye;

- (bool)generic:(NSString*)string;

// pipe filedescriptors to pass data back and forth from Sofia to the App
//@property int sofia_input_fd;
//@property int sofia_output_fd;
//@property NSArray * writePipe;
//@property NSArray * readPipe;
@end

