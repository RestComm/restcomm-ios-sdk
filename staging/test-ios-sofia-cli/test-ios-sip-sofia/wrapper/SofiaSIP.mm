//
//  SofiaSIP.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/27/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include "sofsip_cli.h"
#include <sys/event.h>
#include <string>

#import "SofiaSIP.h"

// those are used both in the context of SofiaSIP class and outside (i.e. C callbacks); lets make them global
int write_pipe[2];
int read_pipe[2];

@implementation SofiaSIP

static int handleSofiaInput(std::string input, int fd)
{
    if (input == "auth") {
        // reply to an authentication request with the credentials
        pipeToSofia("k 1234", write_pipe[1]);
    }
    return 0;
}

// receive incoming events from sofiaSIP via pipe
static void inputCallback(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info) {
    int fd = CFFileDescriptorGetNativeDescriptor(fdref);
    char buf[100] = "";
    if (read(fd, buf, sizeof(buf)) == -1) {
        perror("read from pipe in App");
        exit(EXIT_FAILURE);
    }
    else {
        handleSofiaInput(buf, fd);
    }
    
    CFFileDescriptorInvalidate(fdref);
    CFRelease(fdref);  // run loop cycle ended; the CFFileDescriptorRef needs to be released (next cycle will re-allocate it)
    
    // important: apparently the source only stays in the run loop for one cycle,
    // so we need to add it after each cycle
    addFdSourceToRunLoop(fd);
}

static void addFdSourceToRunLoop(int fd)
{
    // add input fd to the main run loop as a source. That way we can get notification without the need of an extra thread :)
    CFFileDescriptorRef fdref = CFFileDescriptorCreate(kCFAllocatorDefault, fd, false, inputCallback, NULL);
    CFFileDescriptorEnableCallBacks(fdref, kCFFileDescriptorReadCallBack);
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fdref, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
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
        sofsip_loop(0, NULL, write_pipe[0], read_pipe[1]/*[[self.readPipe objectAtIndex:1] intValue]*/);
    });

    addFdSourceToRunLoop(read_pipe[0]);
    
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

- (bool)authenticate:(NSString*)string
{
    NSString* cmd = [NSString stringWithFormat:@"k %@", string];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)bye
{
    NSString* cmd = [NSString stringWithFormat:@"x"];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)generic:(NSString*)string
{
    [self pipeToSofia:string];
    
    return true;
}

@end
