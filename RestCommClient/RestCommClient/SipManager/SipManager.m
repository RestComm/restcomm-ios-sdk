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

#include <sys/event.h>
//#include <string>

#include "sofsip_cli.h"
#include "ssc_sip.h"
#include "gst_ios_init.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "RTCPeerConnectionFactory.h"

#import "SipManager.h"

/* TODOs:
 * - There's no way you can stop a call before it is established (i.e. while it is ringing)
 * - When receiving a call, cannot hangup (Issue #2)
 * - When issuing a call towards Alice (WebRTC) and Alice answers nothing happens; I don't see any answer in tcpdump. Could it be a WebRTC issue?
 *
 */

// those are used both in the context of SipManager class and outside (i.e. C callbacks); lets make them global
int write_pipe[2];
int read_pipe[2];

@implementation SipManager
@synthesize muted;
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

#pragma mark - RTCSessionDescriptionDelegate WebRTC <-> Sofia communication: MediaDelegate protocol
- (void)mediaController:(MediaWebRTC *)media didCreateSdp:(NSString *)sdpString isInitiator:(BOOL)initiator
{
    if (initiator) {
        [self pipeToSofia:[NSString stringWithFormat:@"webrtc-sdp %@", sdpString]];
    }
    else {
        [self pipeToSofia:[NSString stringWithFormat:@"webrtc-sdp-called %@", sdpString]];
    }
}

// TODO: webrtc module has come up with a local video track, we need to render it inside a UIView and return that
// view back to RCConnection. That way the application doesn't need to know about RTCVideoTracks, which are
// webrtc implementation details
- (void)mediaController:(MediaWebRTC *)mediaController didReceiveLocalVideoTrack:(RTCVideoTrack *)videoTrack
{
    
}

- (void)mediaController:(MediaWebRTC *)mediaController didReceiveRemoteVideoTrack:(RTCVideoTrack *)videoTrack
{
    
}

/*
- (void)peerDisconnected:(MediaWebRTC *)media withData:(NSString *)data
{
    [self bye];
    //[self pipeToSofia:[NSString stringWithFormat:@"webrtc-sdp %@", data]];
}
 */

// notice that we can make this an Objective-C method as well, if we want
- (int)handleSofiaInput:(struct SofiaReply *) reply fd:(int) fd
{
    if (reply->rc == REPLY_AUTH) {
        // reply to an authentication request with the credentials
        pipeToSofia("k 1234", write_pipe[1]);
    }
    else if (reply->rc == INCOMING_CALL) {
        // we have an incoming call, we need to ring
        
        // the incoming message has first the address of the Sofia operation (until the first space)
        // and then the SDP, let's parse them into separate strings
        NSString * string = [NSString stringWithUTF8String:reply->text];
        NSRange range = [string rangeOfString:@" "];
        NSString * address = [string substringToIndex:range.location];
        NSString * sdp = [string substringFromIndex:range.location + 1];

        // TODO: initialize WebRTC module centrally
        //self.media = [[MediaWebRTC alloc] initWithDelegate:self];
        [self.media connect:address sdp:sdp isInitiator:NO];

        // Once WebRTC implementation is working re-enable the event below (maybe it needs to be relocated though)
        [self.deviceDelegate callArrived:self];
    }
    else if (reply->rc == OUTGOING_RINGING) {
        // we have an incoming call, we need to ring
        [self.connectionDelegate outgoingRinging:self];
    }
    else if (reply->rc == OUTGOING_ESTABLISHED) {
        [self.connectionDelegate outgoingEstablished:self];
        // call is established, send the SDP over to WebRTC
        [self.media processSignalingMessage:reply->text type:kARDSignalingMessageTypeAnswer];
    }
    else if (reply->rc == INCOMING_MSG) {
        NSString* msg = [NSString stringWithCString:reply->text encoding:NSUTF8StringEncoding];
        [self.deviceDelegate messageArrived:self withData:msg];
    }
    else if (reply->rc == WEBRTC_SDP_REQUEST) {
        // INVITE has been requested in Sofia, need to initialize WebRTC
        //self.media = [[MediaWebRTC alloc] initWithDelegate:self];
        [self.media connect:[NSString stringWithCString:reply->text encoding:NSUTF8StringEncoding] sdp:nil isInitiator:YES];
    }
    else if (reply->rc == OUTGOING_BYE_RESPONSE || reply->rc == INCOMING_BYE) {
        [self.media disconnect];
        //self.media = nil;
    }
    
    return 0;
}

// receive incoming events from sofia SIP via pipe
static void inputCallback(CFFileDescriptorRef fdref, CFOptionFlags callBackTypes, void *info)
{
    // which fd corresponds to the given fdref
    int fd = CFFileDescriptorGetNativeDescriptor(fdref);
    
    // remember, 'info' is actually the Objective-C object 'SipManager', so here we are casting
    // it properly so that we can then use it to access Objective-C resources from C (access to App UI elements, etc)
    SipManager * sipManager = (__bridge id) info;
    struct SofiaReply reply;
    
    // TODO: what if message is truncated?
    if (read(fd, &reply, sizeof(reply)) == -1) {
        perror("read from pipe in App");
        exit(EXIT_FAILURE);
    }
    else {
        [sipManager handleSofiaInput:&reply fd:fd];
    }
    
    CFFileDescriptorInvalidate(fdref);
    CFRelease(fdref);  // run loop cycle ended; the CFFileDescriptorRef needs to be released (next cycle will re-allocate it)
    
    // important: apparently the source only stays in the run loop for one cycle,
    // so we need to add it after each cycle
    [sipManager addFdSourceToRunLoop:fd];
}

- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate
{
    self = [super init];
    if (self) {
        self.deviceDelegate = deviceDelegate;
        self.params = [[NSMutableDictionary alloc] init];
        [RTCPeerConnectionFactory initializeSSL];
        self.media = [[MediaWebRTC alloc] initWithDelegate:self];
    }
    return self;
}

- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate andParams:(NSDictionary*)params
{
    self = [self initWithDelegate:deviceDelegate];
    [self.params setDictionary:params];
    //[self setParams:params];
    
    return self;
}

- (void)dealloc {
    [RTCPeerConnectionFactory deinitializeSSL];
    self.media = nil;
}

// initialize sofia
- (bool)eventLoop
{
    if (pipe(write_pipe) == -1 || pipe(read_pipe) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }
    
    NSError *setCategoryError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&setCategoryError];
    
    
    // initialize gstreamer stuff
    gst_ios_init();
    
    // sofia has its own event loop, so we need to call it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // communicate with sip sofia via the pipe
        sofsip_loop(NULL, 0, write_pipe[0], read_pipe[1]);
    });
    
    [self addFdSourceToRunLoop:read_pipe[0]];
    
    return true;
}

// use a plain C function for the actual transmission, as we will be using it from our C callback as well
ssize_t pipeToSofia(const char * msg, int fd)
{
    char delimitedMsg[strlen(msg) + 2];
    // important: I'm adding a '$' at the end to mark end of command, because in the
    // receiving side more than one commands might be received in one go
    strcpy(delimitedMsg, msg);
    strcat(delimitedMsg, "$");
    ssize_t rc = write(fd, delimitedMsg, strlen(delimitedMsg));
    if (rc == -1) {
        NSLog(@"Error writing to pipe");
    }
    return rc;
}

- (ssize_t)pipeToSofia:(NSString*)cmd
{
    // TODO: write might not send all the string, make sure that the operation is repeated until all the string is sent
    return pipeToSofia([cmd cStringUsingEncoding:NSUTF8StringEncoding], write_pipe[1]);
}

- (bool)register:(NSString*)registrar
{
    // convert args to cli command
    NSString* cmd = [NSString stringWithFormat:@"r %@", registrar];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)message:(NSString*)msg to:(NSString*)recipient;
{
    NSString* cmd = [NSString stringWithFormat:@"m %@ %@", recipient, msg];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)invite:(NSString*)recipient
{
    NSString* cmd = [NSString stringWithFormat:@"i %@", recipient];
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

- (bool)cancel
{
    NSString* cmd = [NSString stringWithFormat:@"c"];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)bye
{
    NSString* cmd = [NSString stringWithFormat:@"b"];
    [self pipeToSofia:cmd];
    
    return true;
}

// mostly for troubleshooting. Sends the give cli command with no interpretation
- (bool)cli:(NSString*)cmd
{
    [self pipeToSofia:cmd];
    
    return true;
}

// update given params in the SIP stack
- (bool)updateParams:(NSDictionary*)params
{
    NSString* cmd;
    for (id key in params) {
        if ([key isEqualToString:@"aor"]) {
            cmd = [NSString stringWithFormat:@"addr %@", [params objectForKey:key]];
            [self pipeToSofia:cmd];
            
        }
        else if ([key isEqualToString:@"registrar"]) {
            cmd = [NSString stringWithFormat:@"r %@", [params objectForKey:key]];
            [self pipeToSofia:cmd];
        }
    }
    //NSLog(@"key=%@ value=%@", key, [params objectForKey:key]);
    return true;
}

- (BOOL)getMuted {
    return self.muted;
}

- (void)setMuted:(BOOL)isMuted {
    muted = isMuted;
    // TODO: need to initialize WebRTC as soon as SipManager comes up
    if (muted == YES) {
        [self.media mute];
    }
    else {
        [self.media unmute];
    }
}

@end
