//
//  SofiaSIP.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include <sys/event.h>
#include <string>

#include "sofsip_cli.h"
#include "ssc_sip.h"

#import "SofiaSIP.h"

/* TODOs:
 * - There's no way you can stop a call before it is established (i.e. while it is ringing)
 * - When receiving a call, cannot hangup (Issue #2)
 * - When issuing a call towards Alice (WebRTC) and Alice answers nothing happens; I don't see any answer in tcpdump. Could it be a WebRTC issue?
 *
 */

// those are used both in the context of SofiaSIP class and outside (i.e. C callbacks); lets make them global
int write_pipe[2];
int read_pipe[2];

@implementation SofiaSIP

// notice that we can make this an Objective-C method as well, if we want
//static int handleSofiaInput(SofiaReply * reply, int fd)
- (int)handleSofiaInput:(SofiaReply *) reply fd:(int) fd
{
    if (reply->rc == REPLY_AUTH) {
        // reply to an authentication request with the credentials
        pipeToSofia("k 1234", write_pipe[1]);
    }
    else if (reply->rc == INCOMING_CALL) {
        // we have an incoming call, we need to ring
        [self.viewController incomingCall];
    }
    else if (reply->rc == INCOMING_MSG) {
        // we have an incoming call, we need to ring
        NSString* msg = [NSString stringWithCString:reply->text encoding:NSUTF8StringEncoding];
        [self.viewController incomingMsg:msg];
    }
    return 0;
}

// receive incoming events from sofiaSIP via pipe
static void inputCallback(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info) {
    // which fd corresponds to the given fdref
    int fd = CFFileDescriptorGetNativeDescriptor(fdref);
    SofiaSIP * sofiaSIP = (__bridge id) info;
    SofiaReply reply;
    if (read(fd, &reply, sizeof(reply)) == -1) {
        perror("read from pipe in App");
        exit(EXIT_FAILURE);
    }
    else {
        //handleSofiaInput(&reply, fd);
        [sofiaSIP handleSofiaInput:&reply fd:fd];
    }
    
    CFFileDescriptorInvalidate(fdref);
    CFRelease(fdref);  // run loop cycle ended; the CFFileDescriptorRef needs to be released (next cycle will re-allocate it)
    
    // important: apparently the source only stays in the run loop for one cycle,
    // so we need to add it after each cycle
    
    // remember, 'info' is actually the Objective-c object 'SofiaSIP', so here we are calling
    // an objective-C method from a C function. That will give us better access to App UI elements
    [sofiaSIP addFdSourceToRunLoop:fd];
    //addFdSourceToRunLoop(fd);
}

- (id)initWithController:(ViewController*)viewController
{
    self = [super init];
    if (self) {
        self.viewController = viewController;
    }
    return self;
}

// add input fd to the main run loop as a source. That way we can get notification without the need of an extra thread :)
//static void addFdSourceToRunLoop(int fd)
- (void) addFdSourceToRunLoop:(int)fd
{
    CFFileDescriptorContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    CFFileDescriptorRef fdref = CFFileDescriptorCreate(kCFAllocatorDefault, fd, false, inputCallback, &context);
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

// initialize sofia
- (bool)initialize
{
    if (pipe(write_pipe) == -1 || pipe(read_pipe) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }
    
    // sofia has its own event loop, so we need to call it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // communicate with sip sofia via the pipe
        sofsip_loop(0, NULL, write_pipe[0], read_pipe[1]);
    });

    [self addFdSourceToRunLoop:read_pipe[0]];
    
    // the registrar is builting to the cli for now
    [self register:@""];

    return true;
}

// use a plain C function for the actual transmission, as we will be using it from our C callback as well
int pipeToSofia(const char * msg, int fd)
{
    return write(fd, msg, strlen(msg));
}

- (int)pipeToSofia:(NSString*)cmd
{
    // TODO: write might not send all the string, make sure that the operation is repeated until all the string is sent
    return pipeToSofia([cmd UTF8String], write_pipe[1]/*[[self.writePipe objectAtIndex:1] intValue]*/);
}

- (bool)register:(NSString*)registrar
{
    // convert args to cli command
    NSString* cmd = [NSString stringWithFormat:@"r %@", registrar];
    [self pipeToSofia:cmd];

    return true;
}

- (bool)sendMessage:(NSString*)msg to:(NSString*)recepient;
{
    NSString* cmd = [NSString stringWithFormat:@"m %@ %@", recepient, msg];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)invite:(NSString*)recepient
{
    NSString* cmd = [NSString stringWithFormat:@"i %@", recepient];
    [self pipeToSofia:cmd];

    return true;
}

// anwer incoming call
- (bool)answer
{
    NSString* cmd = [NSString stringWithFormat:@"a"];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)decline
{
    NSString* cmd = [NSString stringWithFormat:@"d"];
    [self pipeToSofia:cmd];

    return true;
}

- (bool)authenticate:(NSString*)string
{
    NSString* cmd = [NSString stringWithFormat:@"k %@", string];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)bye
{
    NSString* cmd = [NSString stringWithFormat:@"b"];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)generic:(NSString*)string
{
    [self pipeToSofia:string];
    
    return true;
}

@end
