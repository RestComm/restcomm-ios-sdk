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
#include <iostream>
#include <map>
//#include "gst_ios_init.h"

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

@interface SipManager ()
@property BOOL restartSignalling;
@property NSLock * restartSignallingLock;
@end

@implementation SipManager
@synthesize muted;
@synthesize videoMuted;
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
    [self.connectionDelegate sipManager:self receivedLocalVideo:videoTrack];
}

- (void)mediaController:(MediaWebRTC *)mediaController didReceiveRemoteVideoTrack:(RTCVideoTrack *)videoTrack
{
    [self.connectionDelegate sipManager:self receivedRemoteVideo:videoTrack];
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
        NSString * string = [NSString stringWithFormat:@"k %@", [self.params objectForKey:@"password"]];
        pipeToSofia([string UTF8String], write_pipe[1]);
    }
    else if (reply->rc == INCOMING_CALL) {
        // we have an incoming call, we need to ring
        
        // Once WebRTC implementation is working re-enable the event below (maybe it needs to be relocated though)
        [self.deviceDelegate callArrived:self];
    }
    else if (reply->rc == ANSWER_PRESSED) {
        // the incoming message has first the address of the Sofia operation (until the first space)
        // and then the SDP, let's parse them into separate strings
        NSString * string = [NSString stringWithUTF8String:reply->text.c_str()];
        NSRange range = [string rangeOfString:@" "];
        NSString * address = [string substringToIndex:range.location];
        NSString * sdp = [string substringFromIndex:range.location + 1];

        self.media = [[MediaWebRTC alloc] initWithDelegate:self];
        [self.media connect:address sdp:sdp isInitiator:NO withVideo:self.videoAllowed];
    }
    else if (reply->rc == OUTGOING_RINGING) {
        // we have an incoming call, we need to ring
        [self.connectionDelegate outgoingRinging:self];
    }
    else if (reply->rc == OUTGOING_ESTABLISHED) {
        [self.connectionDelegate outgoingEstablished:self];
        // call is established, send the SDP over to WebRTC
        [self.media processSignalingMessage:reply->text.c_str() type:kARDSignalingMessageTypeAnswer];
    }
    else if (reply->rc == INCOMING_ESTABLISHED) {
        [self.connectionDelegate incomingEstablished:self];
    }
    else if (reply->rc == INCOMING_MSG) {
        NSString* whole = [NSString stringWithCString:reply->text.c_str() encoding:NSUTF8StringEncoding];
        NSString* username = [whole componentsSeparatedByString:@"|"][0];
        NSString* msg = [whole componentsSeparatedByString:@"|"][1];
        [self.deviceDelegate messageArrived:self withData:msg from:username];
    }
    else if (reply->rc == INCOMING_CANCELLED) {
        [self.connectionDelegate incomingCancelled:self];
    }
    else if (reply->rc == OUTGOING_CANCELLED) {
        [self.media disconnect];
        self.media = nil;
        [self.connectionDelegate outgoingCancelled:self];
    }
    else if (reply->rc == OUTGOING_DECLINED) {
        [self.media disconnect];
        self.media = nil;
        [self.connectionDelegate outgoingDeclined:self];
    }
    else if (reply->rc == WEBRTC_SDP_REQUEST) {
        // INVITE has been requested in Sofia, need to initialize WebRTC
        self.media = [[MediaWebRTC alloc] initWithDelegate:self];
        [self.media connect:[NSString stringWithCString:reply->text.c_str() encoding:NSUTF8StringEncoding]
                        sdp:nil isInitiator:YES withVideo:self.videoAllowed];
    }
    else if (reply->rc == OUTGOING_BYE_RESPONSE || reply->rc == INCOMING_BYE) {
        [self.media disconnect];
        self.media = nil;
        [self.connectionDelegate bye:self];
    }
    else if (reply->rc == SIGNALLING_INITIALIZED) {
        // delay execution of my block for 1 seconds.
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.deviceDelegate signallingInitialized:self];
        //});
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
    
    ssize_t size = 0;
    char buf[65536] = "";
    if ((size = read(fd, &buf, sizeof(buf))) == -1) {
        perror("read from pipe in App");
        exit(EXIT_FAILURE);
    }
    else {
        string incomingMsg(buf, size);
        //printf("\n######### Receiving from Sofia, res: %lu buf: %s\n", size, buf);
        while (1) {
            // remember, Deserialize() will return the remaining commands after it parses the first, if applicable
            incomingMsg = reply.Deserialize(incomingMsg);
            //NSLog(@"\n@@@@@@@@@ App << Sofia: %d, %s", reply.rc, reply.text.c_str());
            [sipManager handleSofiaInput:&reply fd:fd];
            
            if (incomingMsg == "") {
                break;
            }
        }
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
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *error = nil;
        if (![session setCategory:AVAudioSessionCategoryPlayAndRecord
                      withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker /*AVAudioSessionCategoryOptionMixWithOthers*/
                            error:&error]) {
            // handle error
            NSLog(@"Error setting AVAudioSession category");
        }
        /*
        if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                         error:&error]) {
            NSLog(@"Error overriding output to speaker");
        }
         */
        self.videoAllowed = NO;
        
        if (![session setActive:YES error:&error]) {
            NSLog(@"Error activating audio session");
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didSessionRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        self.deviceDelegate = deviceDelegate;
        self.params = [[NSMutableDictionary alloc] init];
        [RTCPeerConnectionFactory initializeSSL];
        // do we want to restart Sofia facilities when shutting down (i.e. after shutdown is successful)
        //self.restartSignalling = NO;
        //self.restartSignallingLock = [[NSLock alloc] init];

        //self.media = [[MediaWebRTC alloc] initWithDelegate:self];
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

- (void)didSessionRouteChange:(NSNotification *)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            // Set speaker as default route
            NSError* error;
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        }
            break;
            
        default:
            break;
    }
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
    
    // add 'listener' to the input pipe *before* we initialize Sofia, so that we guarantee that
    // no Sofia event can be missed
    [self addFdSourceToRunLoop:read_pipe[0]];
    
    // sofia has its own event loop, so we need to call it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //while (1) {
            // communicate with sip sofia via the pipe
            sofsip_loop(NULL, 0, write_pipe[0], read_pipe[1], [[self.params objectForKey:@"aor"] UTF8String],
                        [[self.params objectForKey:@"registrar"] UTF8String]);
            NSLog(@"Stopped eventLoop");
            /*
            [_restartSignallingLock lock];
            if (!self.restartSignalling) {
                [_restartSignallingLock unlock];
                break;
            }
            else {
                NSLog(@"Restarting eventLoop");
                self.restartSignalling = NO;
            }
            [_restartSignallingLock unlock];
            */
        //}
        
    });
    
    return true;
}

// use a plain C function for the actual transmission, as we will be using it from our C callback as well
ssize_t pipeToSofia(const char * msg, int fd)
{
    char * delimitedMsg = (char*)malloc(strlen(msg) + 2);
    // important: I'm adding a '$' at the end to mark end of command, because in the
    // receiving side more than one commands might be received in one go
    strcpy(delimitedMsg, msg);
    strcat(delimitedMsg, "$");
    ssize_t rc = write(fd, delimitedMsg, strlen(delimitedMsg));
    if (rc == -1) {
        NSLog(@"Error writing to pipe");
    }
    free(delimitedMsg);
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

- (bool)unregister:(NSString*)registrar
{
    NSString* cmd = nil;
    if (registrar) {
        // convert args to cli command
        cmd = [NSString stringWithFormat:@"u %@", registrar];
    }
    else {
        cmd = [NSString stringWithFormat:@"u"];
    }
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)message:(NSString*)msg to:(NSString*)recipient;
{
    NSString* cmd = [NSString stringWithFormat:@"m %@ %@", recipient, msg];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)invite:(NSString*)recipient withVideo:(BOOL)video
{
    self.videoAllowed = video;
    NSString* cmd = [NSString stringWithFormat:@"i %@", recipient];
    [self pipeToSofia:cmd];
    
    return true;
}

// anwer incoming call
- (bool)answerWithVideo:(BOOL)video
{
    self.videoAllowed = video;
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

- (bool)shutdown:(BOOL)restart
{
    NSString* cmd = [NSString stringWithFormat:@"q"];
    if (restart == YES) {
        cmd = @"qr";
    }
    [self pipeToSofia:cmd];

    /*
    [_restartSignallingLock lock];
    self.restartSignalling = restart;
    [_restartSignallingLock unlock];
     */

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
            // save key/value to local params dictionary for later use
            [self.params setObject:[params objectForKey:key] forKey:key];
        }
        else if ([key isEqualToString:@"registrar"]) {
            cmd = [NSString stringWithFormat:@"r %@", [params objectForKey:key]];
            [self pipeToSofia:cmd];
            // save key/value to local params dictionary for later use
            [self.params setObject:[params objectForKey:key] forKey:key];
        }
        else if ([key isEqualToString:@"password"]) {
            [self.params setObject:[params objectForKey:@"password"] forKey:@"password"];
        }
    }
    // when no params are passed, we default to registering to restcomm with the stored registrar at self.params
    if (params == nil) {
        cmd = [NSString stringWithFormat:@"r %@", [self.params objectForKey:@"registrar"]];
        [self pipeToSofia:cmd];
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

- (BOOL)getVideoMuted {
    return self.videoMuted;
}

- (void)setVideoMuted:(BOOL)isMuted {
    videoMuted = isMuted;
    // TODO: need to initialize WebRTC as soon as SipManager comes up
    if (videoMuted == YES) {
        [self.media muteVideo];
    }
    else {
        [self.media unmuteVideo];
    }
}


@end
