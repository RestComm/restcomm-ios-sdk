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
#include "sofsip_cli.h"
#include "ssc_sip.h"
#include <iostream>
#include <map>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
//#import "WebRTC/RTCPeerConnectionFactory.h"

#import "RestCommClient.h"
#import "SipManager.h"
#import "RCUtilities.h"
#import "common.h"

// those are used both in the context of SipManager class and outside (i.e. C callbacks); lets make them global
int write_pipe[2];
int read_pipe[2];

@interface SipManager ()
@property int signallingInstances;
@property NSRecursiveLock * signallingInstancesLock;
@property NSMutableDictionary * activeCallParams;
@end

@implementation SipManager
@synthesize muted;
@synthesize videoMuted;
@synthesize speaker;
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
- (void)mediaController:(MediaWebRTC *)mediaController didCreateSdp:(NSString *)sdpString isInitiator:(BOOL)initiator
{
    if (self.media.state == kARDAppClientStateDisconnected) {
        RCLogError("[mediaController:didCreateSdp:isInitiator:] media disconnected; bailing");
        return;
    }
    
    if (initiator) {
        // Sofia expects these in the message:
        // - destination
        // - SDP
        // - sip headers if applicable
        NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObject:[self.activeCallParams objectForKey:@"destination" ]
                                                                        forKey:@"destination"];
        [args setValue:sdpString forKey:@"sdp"];
        [args setValue:[self.params objectForKey:@"password"] forKey:@"password"];
        
        // serialize sip-headers
        if ([self.activeCallParams objectForKey:@"sip-headers"]) {
            NSMutableString *serializedHeaders = [NSMutableString string];
            for (NSString* key in [[self.activeCallParams objectForKey:@"sip-headers"] allKeys]){
                [serializedHeaders appendFormat:@"%@:%@", key, [[self.activeCallParams objectForKey:@"sip-headers"] objectForKey:key]];
                [serializedHeaders appendString:@"\r\n"];
            }
            [args setValue:serializedHeaders forKey:@"sip-headers"];
        }

        NSString* cmd = [NSString stringWithFormat:@"i %@", [RCUtilities stringifyDictionary:args]];
        [self pipeToSofia:cmd];
    }
    else {
        // This logic was for when media processing started when INVITE arrived for incoming calls
        // (as opposed to when we press answer as it is now). Let's keep it around since we'll be
        // revisiting this at some point in the future
        /*
        [self.activeCallParams setObject:sdpString forKey:@"sdp"];
        [self.activeCallParams setObject:@(YES) forKey:@"incoming-call-gathering-complete"];
        if ([self.activeCallParams objectForKey:@"incoming-call-was-answered"]) {
            NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObject:[self.activeCallParams objectForKey:@"sdp"]
                                                                            forKey:@"sdp"];
            [self pipeToSofia:[NSString stringWithFormat:@"a %@", [RCUtilities stringifyDictionary:args]]];
        }
         */
        NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObject:sdpString
                                                                        forKey:@"sdp"];

        [self pipeToSofia:[NSString stringWithFormat:@"a %@", [RCUtilities stringifyDictionary:args]]];
    }
}

- (void)mediaController:(MediaWebRTC *)mediaController didError:(NSError *)error
{
    [self.connectionDelegate sipManager:self didMediaError:error];
}

// TODO: webrtc module has come up with a local video track, we need to render it inside a UIView and return that
// view back to RCConnection. That way the application doesn't need to know about RTCVideoTracks, which are
// webrtc implementation details
- (void)mediaController:(MediaWebRTC *)mediaController didReceiveLocalVideoTrack:(RTCVideoTrack *)videoTrack
{
    [self.connectionDelegate sipManager:self didReceiveLocalVideo:videoTrack];
}

- (void)mediaController:(MediaWebRTC *)mediaController didReceiveRemoteVideoTrack:(RTCVideoTrack *)videoTrack
{
    [self.connectionDelegate sipManager:self didReceiveRemoteVideo:videoTrack];
}

- (void)mediaController:(MediaWebRTC *)mediaController didIceConnectAsInitiator:(BOOL)initiator;
{
    if (initiator) {
        [self.connectionDelegate sipManagerDidReceiveOutgoingEstablished:self];
    }
    else {
        [self.connectionDelegate sipManagerDidReceiveIncomingEstablished:self];
    }
}

// notice that we can make this an Objective-C method as well, if we want
- (int)handleSofiaInput:(struct SofiaReply *) reply fd:(int) fd
{
    if (reply->rc == REPLY_AUTH) {
        // reply to an authentication request with the credentials
        NSString * string = [NSString stringWithFormat:@"k %@", [self.params objectForKey:@"password"]];
        pipeToSofia([string UTF8String], write_pipe[1]);
    }
    else if (reply->rc == INCOMING_CALL) {
        // we have an incoming call, we need to start media processing and notify the application
        [self.activeCallParams removeAllObjects];

        NSError * error;
        NSString * string = [NSString stringWithUTF8String:reply->text.c_str()];
        NSData * data = [string dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary * args = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];

        [self.deviceDelegate sipManagerDidReceiveCall:self from:[RCUtilities usernameFromUri:[args objectForKey:@"sip-uri"]]];
        [self.activeCallParams setObject:[args objectForKey:@"sdp"] forKey:@"sdp"];

        // This logic was for when media processing started when INVITE arrived for incoming calls
        // (as opposed to when we press answer as it is now). Let's keep it around since we'll be
        // revisiting this at some point in the future
        /*
        if (!self.media) {
            self.media = [[MediaWebRTC alloc] initWithDelegate:self];
            [self.media connect:nil sdp:[args objectForKey:@"sdp"] isInitiator:NO withVideo:self.videoAllowed];
        }
        else {
            // report error
            NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                        code:ERROR_WEBRTC_ALREADY_INITIALIZED
                                                    userInfo:@{NSLocalizedDescriptionKey : @"Error: Could not initialize webrtc; already initialized"}];
            
            [self.connectionDelegate sipManager:self didSignallingError:error];
        }
         */
    }
    else if (reply->rc == ERROR_INITIALIZING_SIGNALING) {
        // we have an incoming call, we need to ring
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                    code:reply->rc
                                                userInfo:@{NSLocalizedDescriptionKey : @(reply->text.c_str())}];

        [self.deviceDelegate sipManager:self didSignallingError:error];
    }
    else if (reply->rc == OUTGOING_RINGING) {
        // we have an incoming call, we need to ring
        [self.connectionDelegate sipManagerDidReceiveOutgoingRinging:self];
    }
    else if (reply->rc == OUTGOING_ESTABLISHED) {
        //[self.connectionDelegate sipManagerDidReceiveOutgoingEstablished:self];
        // call is established, send the SDP over to WebRTC
        [self.media processSignalingMessage:reply->text.c_str() type:kARDSignalingMessageTypeAnswer];
    }
    else if (reply->rc == INCOMING_ESTABLISHED) {
        //[self.connectionDelegate sipManagerDidReceiveIncomingEstablished:self];
    }
    else if (reply->rc == INCOMING_MSG) {
        NSString* whole = [NSString stringWithCString:reply->text.c_str() encoding:NSUTF8StringEncoding];
        NSString* username = [whole componentsSeparatedByString:@"|"][0];
        NSString* msg = [whole componentsSeparatedByString:@"|"][1];
        [self.deviceDelegate sipManager:self didReceiveMessageWithData:msg from:[RCUtilities usernameFromUri:username]];
    }
    else if (reply->rc == INCOMING_CANCELLED) {
        [self.connectionDelegate sipManagerDidReceiveIncomingCancelled:self];
    }
    else if (reply->rc == OUTGOING_CANCELLED) {
        [self disconnectMedia];
        [self.connectionDelegate sipManagerDidReceiveOutgoingCancelled:self];
    }
    else if (reply->rc == OUTGOING_DECLINED) {
        [self disconnectMedia];
        [self.connectionDelegate sipManagerDidReceiveOutgoingDeclined:self];
    }
    else if (reply->rc == REGISTER_SUCCESS) {
        [self.deviceDelegate sipManagerDidRegisterSuccessfully:self];
    }
    else if (reply->rc == ERROR_REGISTER_GENERIC || reply->rc == ERROR_REGISTER_AUTHENTICATION || reply->rc == ERROR_REGISTER_TIMEOUT ||
             reply->rc == ERROR_SIP_REGISTER_URI_INVALID || reply->rc == ERROR_REGISTER_SERVICE_UNAVAILABLE) {
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                    code:reply->rc
                                                userInfo:@{NSLocalizedDescriptionKey : @(reply->text.c_str())}];
        
        [self.deviceDelegate sipManager:self didSignallingError:error];
    }
    /*
    else if (reply->rc == REGISTER_ERROR_AUTHENTICATION) {
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                    code:ERROR_REGISTERING_AUTHENTICATION
                                                userInfo:@{NSLocalizedDescriptionKey : @(reply->text.c_str())}];
        
        [self.deviceDelegate sipManager:self didSignallingError:error];
    }
     */
    else if (reply->rc == ERROR_SIP_INVITE_GENERIC || reply->rc == ERROR_SIP_INVITE_AUTHENTICATION || reply->rc == ERROR_SIP_INVITE_TIMEOUT ||
             reply->rc == ERROR_SIP_INVITE_NOT_FOUND || reply->rc == ERROR_SIP_INVITE_SIP_URI_INVALID) {
        [self disconnectMedia];
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                       code:reply->rc
                                                   userInfo:@{NSLocalizedDescriptionKey : @(reply->text.c_str())}];

        [self.connectionDelegate sipManager:self didSignallingError:error];
    }
    else if (reply->rc == ERROR_SIP_MESSAGE_GENERIC || reply->rc == ERROR_SIP_MESSAGE_AUTHENTICATION || reply->rc == ERROR_SIP_MESSAGE_TIMEOUT ||
             reply->rc == ERROR_SIP_MESSAGE_NOT_FOUND || reply->rc == ERROR_SIP_MESSAGE_URI_INVALID) {
        NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                    code:reply->rc
                                                userInfo:@{NSLocalizedDescriptionKey : @(reply->text.c_str())}];
        
        [self.deviceDelegate sipManager:self didSignallingError:error];
    }
    else if (reply->rc == OUTGOING_BYE_RESPONSE || reply->rc == INCOMING_BYE) {
        [self disconnectMedia];
        [self.connectionDelegate sipManagerDidReceiveBye:self];
    }
    else if (reply->rc == SIGNALLING_INITIALIZED) {
        // delay execution of my block for 1 seconds.
        //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self.deviceDelegate sipManagerDidInitializedSignalling:self];
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
        while (1) {
            // remember, Deserialize() will return the remaining commands after it parses the first, if applicable
            incomingMsg = reply.Deserialize(incomingMsg);
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
    RCLogNotice("[SipManager initWithDelegate]");
    self = [super init];
    if (self) {
        self.activeCallParams = [[NSMutableDictionary alloc] init];
        
        self.videoAllowed = NO;

        _signallingInstances = 0;
        _signallingInstancesLock = [[NSRecursiveLock alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didSessionRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        self.deviceDelegate = deviceDelegate;
        self.params = [[NSMutableDictionary alloc] init];
        //[RTCPeerConnectionFactory initializeSSL];
        
    }
    return self;
}

- (id)initWithDelegate:(id<SipManagerDeviceDelegate>)deviceDelegate andParams:(NSDictionary*)params
{
    self = [self initWithDelegate:deviceDelegate];
    [self.params setDictionary:params];
    
    return self;
}

- (void)didSessionRouteChange:(NSNotification *)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    RCLogNotice("[SipManager didSessionRouteChange], AudioSession change reason: %d", routeChangeReason);
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonCategoryChange: {
            // Set speaker as default route
            //NSError* error;
            //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
            break;
        }
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            // headphones plugged in
            //NSError* error;
            //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverride error:&error];

            break;
        }
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            break;
        default:
            break;
    }
}

- (void)dealloc {
    RCLogNotice("[SipManager dealloc]");
    //[RTCPeerConnectionFactory deinitializeSSL];
    self.media = nil;
}

// initialize sofia
- (bool)eventLoop
{
    // create a new parameters dictionary used for logging, from which we will remove sensitive information
    NSMutableDictionary * logParameters = [self.params mutableCopy];
    [logParameters removeObjectForKey:@"password"];
    [logParameters removeObjectForKey:@"turn-password"];

    RCLogNotice("[SipManager eventLoop: %s]", [[RCUtilities stringifyDictionary:logParameters] UTF8String]);
    [_signallingInstancesLock lock];
    if (_signallingInstances > 0) {
        RCLogNotice("[SipManager eventLoop] another instance already running; bailing");
        [_signallingInstancesLock unlock];
        [self markForRestartIfShuttingDown];
        return false;
    }
    else {
        _signallingInstances++;
        [_signallingInstancesLock unlock];
    }

    if ([self.params objectForKey:@"signaling-secure"] && [[self.params objectForKey:@"signaling-secure"] boolValue]) {
        if (![self.params objectForKey:@"signaling-certificate-dir"] ||
            ([self.params objectForKey:@"signaling-certificate-dir"] && [[self.params objectForKey:@"signaling-certificate-dir"] isEqualToString:@""])) {
            NSError * error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                         code:ERROR_SECURE_SIGNALLING
                                                     userInfo:@{NSLocalizedDescriptionKey : @"Secure signaling mode specified, but certificate dir is missing" }];
            
            [self.deviceDelegate sipManager:self didSignallingError:error];
            return false;
        }
    }

    if (pipe(write_pipe) == -1 || pipe(read_pipe) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }
    
    // add 'listener' to the input pipe *before* we initialize Sofia, so that we guarantee that
    // no Sofia event can be missed
    [self addFdSourceToRunLoop:read_pipe[0]];
    
    // sofia has its own event loop, so we need to call it asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // remember that in Objective-C, it is valid to send a message to nil, so in this case if certificate-dir doesn't exist as key
        // then nill is returned and then when UTF8String is called on nil, it returns 0x0
        sofsip_loop(NULL, 0, write_pipe[0], read_pipe[1], [[self convert2FullURI:[self.params objectForKey:@"aor"] andDomain:[self.params objectForKey:@"registrar"]] UTF8String],
                    [[self.params objectForKey:@"password"] UTF8String], [[self convert2FullDomain:[self.params objectForKey:@"registrar"]] UTF8String],
                    [[self.params objectForKey:@"signaling-certificate-dir"] UTF8String]);
        
        [_signallingInstancesLock lock];
        _signallingInstances--;
        [_signallingInstancesLock unlock];
        
        RCLogNotice("Stopped eventLoop");
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
    [self.deviceDelegate sipManagerWillUnregister:self];
    
    return true;
}

// Note: messages are the most complex structure to serialize so I had to use JSON to avoid issues.
// That should be the case for all those, but I'm leaving them as they are for now cause at some point
// the whole pipe communication channel will be removed
- (bool)message:(NSString*)msg to:(NSString*)recipient customHeaders:(NSDictionary*)headers
{
    NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObjectsAndKeys:[self convert2FullURI:recipient andDomain:[self.params objectForKey:@"registrar"]], @"destination",
                           msg, @"message", nil];
    if (headers) {
        NSMutableString *serializedHeaders = [NSMutableString string];
        for (NSString* key in [headers allKeys]){
            [serializedHeaders appendFormat:@"%@:%@", key, [headers objectForKey:key]];
            [serializedHeaders appendString:@"\r\n"];
        }
        [args setValue:serializedHeaders forKey:@"sip-headers"];
    }
    [args setValue:[self.params objectForKey:@"password"] forKey:@"password"];
    NSString* cmd = [NSString stringWithFormat:@"m %@", [RCUtilities stringifyDictionary:args]];
    [self pipeToSofia:cmd];
    
    return true;
}

- (bool)invite:(NSString*)recipient withVideo:(BOOL)video customHeaders:(NSDictionary*)headers
{
    self.videoAllowed = video;
    // INVITE has been requested need to initialize WebRTC first
    if (!self.media) {
        [self.activeCallParams removeAllObjects];
        [self.activeCallParams setObject:[self convert2FullURI:recipient andDomain:[self.params objectForKey:@"registrar"]] forKey:@"destination"];
        [self.activeCallParams setObject:@(YES) forKey:@"initiator"];
        if (headers) {
            [self.activeCallParams setObject:headers forKey:@"sip-headers"];
        }
        
        [self permissionFsm:@"" type:@"request" status:NO];
        //[self initializeAudioSession];

        //self.media = [[MediaWebRTC alloc] initWithDelegate:self parameters:self.params];
        //[self.media connect:nil sdp:nil isInitiator:YES withVideo:self.videoAllowed];
    }
    else {
        // media already initialized, cannot continue
        return false;
    }

    return true;
}

// anwer incoming call
- (bool)answerWithVideo:(BOOL)video
{
    self.videoAllowed = video;
    [self.activeCallParams setObject:@(NO) forKey:@"initiator"];
    
    [self permissionFsm:@"" type:@"request" status:NO];
    
    /*
    [self initializeAudioSession];
    if (!self.media) {
        self.media = [[MediaWebRTC alloc] initWithDelegate:self parameters:self.params];
        [self.media connect:nil sdp:[self.activeCallParams objectForKey:@"sdp"] isInitiator:NO withVideo:self.videoAllowed];
    }
    else {
        return false;
    }
     */

    // This logic was for when media processing started when INVITE arrived for incoming calls
    // (as opposed to when we press answer as it is now). Let's keep it around since we'll be
    // revisiting this at some point in the future
    /*
    [self.activeCallParams setObject:@(YES) forKey:@"incoming-call-was-answered"];
    if ([self.activeCallParams objectForKey:@"incoming-call-gathering-complete"]) {
        NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObject:[self.activeCallParams objectForKey:@"sdp"]
                                                                        forKey:@"sdp"];
        [self pipeToSofia:[NSString stringWithFormat:@"a %@", [RCUtilities stringifyDictionary:args]]];
    }
    */
    return true;
}

- (void)handleCall
{
    if (!self.media) {
        [self initializeAudioSession];
        
        self.media = [[MediaWebRTC alloc] initWithDelegate:self parameters:self.params];
        [self.media connect:nil sdp:[self.activeCallParams objectForKey:@"sdp"]
                isInitiator:[[self.activeCallParams objectForKey:@"initiator"] boolValue]
                  withVideo:self.videoAllowed];
    }
    else {
        // TODO: notify App
        RCLogWarn("[SipManager handleCall] MediaWebRTC already initialized");
    }
}

// FSM to handle state changes for permissions
- (void)permissionFsm:(NSString*)mediaType type:(NSString*)type status:(BOOL)status
{
    RCLogNotice("[SipManager permissionFsm:%s type: %s status:%d]", [mediaType UTF8String], [type UTF8String], status);
    if ([type isEqualToString:@"request"]) {
        // entry point
        if ([mediaType isEqualToString:@""]) {
            [self requestPermission:AVMediaTypeAudio];
        }
    }
    else {
        // first check for audio
        if ([mediaType isEqualToString:AVMediaTypeAudio]) {
            if (!status) {
                // audio was rejected, return error and bail
                NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                               code:ERROR_MEDIA_PERMISSION_DENIED
                                                           userInfo:@{ NSLocalizedDescriptionKey: @"Permission denied for microphone, cannot continue call" }];

                [self.connectionDelegate sipManager:self didMediaError:error];
                return;
            }
            // call is video, ask permission for video as well
            if (self.videoAllowed) {
                [self requestPermission:AVMediaTypeVideo];
            }
            else {
                [self handleCall];
            }
        }
        // if video call, second check for video
        if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            if (!status) {
                // video was rejected, fallback to audio call
                NSError *error = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                            code:ERROR_MEDIA_PERMISSION_DENIED
                                                        userInfo:@{ NSLocalizedDescriptionKey: @"Permission denied for camera, cannot continue video call" }];
                
                [self.connectionDelegate sipManager:self didMediaError:error];
                return;
            }

            [self handleCall];
        }
    }
}

- (BOOL)requestPermission:(NSString*)mediaType
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if (authStatus == AVAuthorizationStatusAuthorized) {
        [self permissionFsm:mediaType type:@"response" status:YES];
    }
    else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // not determined yet; need to ask for permission
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            if (granted) {
                [self permissionFsm:mediaType type:@"response" status:YES];
            }
            else {
                [self permissionFsm:mediaType type:@"response" status:NO];
            }
        }];
    }
    else if (authStatus == AVAuthorizationStatusRestricted) {
        // already denied from previous session
        [self permissionFsm:mediaType type:@"response" status:NO];
    }
    else {
        [self permissionFsm:mediaType type:@"response" status:NO];
    }
    
    return NO;
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

- (bool)sendDtmfDigits:(NSString*)dtmf
{
    NSString* cmd = [NSString stringWithFormat:@"info Signal=%@\r\nDuration=100\r\n", dtmf];
    [self pipeToSofia:cmd];
    
    return true;
    
}

- (bool)markForRestartIfShuttingDown
{
    NSString* cmd = [NSString stringWithFormat:@"mr"];
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

    return true;
}

// mostly for troubleshooting. Sends the give cli command with no interpretation
- (bool)cli:(NSString*)cmd
{
    [self pipeToSofia:cmd];
    
    return true;
}

// take a short destination of the form 'bob' and create full SIP URI out of it: 'sip:bob@<domain>'
- (NSString*) convert2FullURI:(NSString*)original andDomain:(NSString*)domain
{
    // TODO: this is a very simplistic way, need to elaborate on it
    NSString * fullUri;

    // if empty don't touch
    if ([original isEqualToString:@""]) {
        return @"";
    }
    else if ([RCUtilities string:original containsString:@"sip:"] || [RCUtilities string:original containsString:@"sips:"]) {
        // if already full URI don't touch
        fullUri = original;
    }
    else {
        // if domain has 'sip:' prefix we need to remove it
        NSString * normalizedDomain = [[domain stringByReplacingOccurrencesOfString:@"sip:" withString:@""] stringByReplacingOccurrencesOfString:@"sips:" withString:@""];
        
        // handle teluri
        if ([RCUtilities string:original containsString:@"tel:"]) {
            // TODO: remove hack: once tel-uri is implemented in Retscomm side remove this
            fullUri = [NSString stringWithFormat:@"%@@%@", [original stringByReplacingOccurrencesOfString:@"tel:" withString:@"sip:"], normalizedDomain];
            
            
            // TODO: add correct code: once tel-uri is implemented add this
            // if tel-uri don't alter it
            //return fullUri;
        }
        else {
            // on any other case build full SIP URI using sip/s: prefix and appending the domain
            
            // if original domain is 'sips:' need to generate sips URI
            if (domain && [RCUtilities string:domain containsString:@"sips:"]) {
                fullUri = [NSString stringWithFormat:@"sips:%@@%@", original, normalizedDomain];
            }
            else {
                fullUri = [NSString stringWithFormat:@"sip:%@@%@", original, normalizedDomain];
            }
        }
    }
    
    // Convert to sips if needed based on the RCDevice param 'signaling-secure'. Although when using registrar this isn't needed
    // as Sofia decides based on registrar SIP-URI (and if sips uses secure signaling for all communications), when using registrar-less the sip uris here decide on that.
    // TODO: when tel-uri is fixed in restcomm side and we change the code in TODO above, we also need to handle secure tel-uri as well here
    if ([self.params objectForKey:@"signaling-secure"] && [[self.params objectForKey:@"signaling-secure"] boolValue] == YES) {
        fullUri = [fullUri stringByReplacingOccurrencesOfString:@"sip:" withString:@"sips:"];
    }
    else {
        fullUri = [fullUri stringByReplacingOccurrencesOfString:@"sips:" withString:@"sip:"];
    }
    
    RCLogNotice("[SipManager convert2FullURI], after conversion: %s", [fullUri UTF8String]);
    
    return fullUri;
}

// take a short domain of the form 'cloud.restcomm.com' and create full SIP domain out of it: 'sip:cloud.restcomm.com'
- (NSString*) convert2FullDomain:(NSString*)original
{
    NSString * fullUri;
    
    //NSString * fullUri = original;
    if ([original isEqualToString:@""]) {
        return @"";
    }
    else if ([RCUtilities string:original containsString:@"sip:"] || [RCUtilities string:original containsString:@"sips:"]) {
        fullUri = original;
    }
    else {
        fullUri = [NSString stringWithFormat:@"sip:%@", original];
    }

    // Convert to sips if needed based on the RCDevice param 'signaling-secure'.
    // Sofia decides based on registrar SIP-URI (and if sips uses secure signaling for all communications)
    if ([self.params objectForKey:@"signaling-secure"] && [[self.params objectForKey:@"signaling-secure"] boolValue] == YES) {
        fullUri = [fullUri stringByReplacingOccurrencesOfString:@"sip:" withString:@"sips:"];
    }
    else {
        fullUri = [fullUri stringByReplacingOccurrencesOfString:@"sips:" withString:@"sip:"];
    }
    
    RCLogNotice("[SipManager convert2FullDomain], after conversion: %s", [fullUri UTF8String]);
    
    return fullUri;
}

// update given params in the SIP stack
// return true if an actual registration was sent and false if it didn't
- (UpdateParamsState)updateParams:(NSDictionary*)params deviceIsOnline:(BOOL)deviceIsOnline
     networkIsOnline:(BOOL)networkIsOnline
{
    UpdateParamsState state = UpdateParamsStateUnassigned;
    // keep in a dictionary all actions we want executed in Sofia, to allow for simpler logic
    NSMutableDictionary * actionsDictionary = [[NSMutableDictionary alloc] init];
    BOOL aorUpdated = NO;
    if (params) {
        // this needs to go first as we will be consulting it in various checks
        if ([params objectForKey:@"signaling-secure"]) {
            if ([[params objectForKey:@"signaling-secure"] boolValue] != [[self.params objectForKey:@"signaling-secure"] boolValue]) {
                // if signaling-secure setting has been updated we need to unregister and re-register
                NSDictionary * unregisterParams = @{
                                                 @"password" : [self.params objectForKey:@"password"],
                                                 };
                
                [actionsDictionary setObject:unregisterParams forKey:@"unregister"];
                
                NSString * aor = @"";
                if ([params objectForKey:@"aor"]) {
                    aor = [params objectForKey:@"aor"];
                }
                
                NSString * password = @"";
                if ([params objectForKey:@"password"]) {
                    password = [params objectForKey:@"password"];
                }

                NSDictionary * registerParams = @{
                                                 @"aor" : [self convert2FullURI:aor andDomain:[params objectForKey:@"registrar"]],
                                                 @"registrar" : [self convert2FullDomain:[params objectForKey:@"registrar"]],
                                                 @"password" : password,
                                                 };
                [actionsDictionary setObject:registerParams forKey:@"register"];

                [self.params setObject:[params objectForKey:@"signaling-secure"] forKey:@"signaling-secure"];
                state = UpdateParamsStateSentRegister;
                aorUpdated = YES;
            }
        }

        if ([params objectForKey:@"registrar"]) {
            if ([[params objectForKey:@"registrar"] isEqualToString:@""]) {
                // registrar-less
                if (![[self.params objectForKey:@"registrar"] isEqualToString:@""]) {
                    if (deviceIsOnline) {
                        // user requested unregister by passing empty string and previously was registered
                        NSDictionary * updatedParams = @{
                                                         @"password" : [self.params objectForKey:@"password"],
                                                         };
                        [actionsDictionary setObject:updatedParams forKey:@"unregister"];
                    }
                    else {
                        // transitioning to registrar-less from non registrar-less when previously we had network connectivity while offline (because register failed)
                        if (networkIsOnline) {
                            state = UpdateParamsStateReestablishedRegistrarless;
                        }
                    }
                }
            }
            else {
                // user requested register
                if (![[self.params objectForKey:@"registrar"] isEqualToString:@""]) {
                    // wasn't previously registraless
                    if (![[params objectForKey:@"registrar"] isEqualToString:[self.params objectForKey:@"registrar"]] && deviceIsOnline) {
                        // user was previously registered and used a different registrar: need to unregister first
                        NSDictionary * updatedParams = @{
                                                         @"password" : [self.params objectForKey:@"password"],
                                                         };
                        
                        [actionsDictionary setObject:updatedParams forKey:@"unregister"];
                    }
                }
                
                NSString * aor = @"";
                if ([params objectForKey:@"aor"]) {
                    aor = [params objectForKey:@"aor"];
                }
                
                NSString * password = @"";
                if ([params objectForKey:@"password"]) {
                    password = [params objectForKey:@"password"];
                }
                
                NSDictionary * updatedParams = @{
                                                 @"aor" : [self convert2FullURI:aor andDomain:[params objectForKey:@"registrar"]],
                                                 @"registrar" : [self convert2FullDomain:[params objectForKey:@"registrar"]],
                                                 @"password" : password,
                                                 };
                [actionsDictionary setObject:updatedParams forKey:@"register"];
                state = UpdateParamsStateSentRegister;
                aorUpdated = YES;
            }
            // save key/value to local params dictionary for later use
            [self.params setObject:[params objectForKey:@"registrar"] forKey:@"registrar"];
        }
        if ([params objectForKey:@"aor"]) {
            [self.params setObject:[params objectForKey:@"aor"] forKey:@"aor"];
            
            // only update AOR if it hasn't been updated in the register above
            if (!aorUpdated) {
                NSDictionary * updatedParams = @{
                                                 @"aor" : [self convert2FullURI:[params objectForKey:@"aor"] andDomain:[self.params objectForKey:@"registrar"]],
                                                 };
                
                [actionsDictionary setObject:updatedParams forKey:@"address"];
            }
        }
        
        // execute actual actions in correct order: first unregister, then register, then address
        if ([actionsDictionary objectForKey:@"unregister"]) {
            NSString* cmd = [NSString stringWithFormat:@"u %@", [RCUtilities stringifyDictionary:[actionsDictionary objectForKey:@"unregister"]]];
            [self pipeToSofia:cmd];
        }
        if ([actionsDictionary objectForKey:@"register"]) {
            NSString* cmd = [NSString stringWithFormat:@"r %@", [RCUtilities stringifyDictionary:[actionsDictionary objectForKey:@"register"]]];
            [self pipeToSofia:cmd];
        }
        if ([actionsDictionary objectForKey:@"address"]) {
            NSString* cmd = [NSString stringWithFormat:@"addr %@", [RCUtilities stringifyDictionary:[actionsDictionary objectForKey:@"address"]]];
            [self pipeToSofia:cmd];
        }
        
            
        if ([params objectForKey:@"password"]) {
            [self.params setObject:[params objectForKey:@"password"] forKey:@"password"];
        }
        if ([params objectForKey:@"turn-url"]) {
            [self.params setObject:[params objectForKey:@"turn-url"] forKey:@"turn-url"];
        }
        if ([params objectForKey:@"turn-enabled"]) {
            [self.params setObject:[params objectForKey:@"turn-enabled"] forKey:@"turn-enabled"];
        }
        if ([params objectForKey:@"turn-username"]) {
            [self.params setObject:[params objectForKey:@"turn-username"] forKey:@"turn-username"];
        }
        if ([params objectForKey:@"turn-password"]) {
            [self.params setObject:[params objectForKey:@"turn-password"] forKey:@"turn-password"];
        }
        if ([params objectForKey:@"turn-candidate-timeout"]) {
            [self.params setObject:[params objectForKey:@"turn-candidate-timeout"] forKey:@"turn-candidate-timeout"];
        }
    }
    else {
        // when no params are passed, we default to registering to restcomm with the stored registrar at self.params
        NSDictionary * updatedParams = @{
                                         @"registrar" : [self convert2FullDomain:[self.params objectForKey:@"registrar"]],
                                         @"password" : [self.params objectForKey:@"password"],
                                         };
        
        NSString* cmd = [NSString stringWithFormat:@"r %@", [RCUtilities stringifyDictionary:updatedParams]];
        [self pipeToSofia:cmd];
    }
    //NSLog(@"key=%@ value=%@", key, [params objectForKey:key]);
    return state;
}

- (BOOL)disconnectMedia
{
    BOOL status = NO;
    if (self.media) {
        [self.media disconnect];
        self.media = nil;
        //[self finalizeAudioSession];
        status = YES;
    }

    [self finalizeAudioSession];
    return status;
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

// enable or disable speaker (effectively disabling or enabling earpiece)
- (void)setSpeaker:(BOOL)isSpeaker {
    speaker = isSpeaker;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    if (speaker == YES) {
        if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                        error:&error]) {
            RCLogError("Error overriding output to speaker");
        }
    }
    else {
        if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone
                                        error:&error]) {
            RCLogError("Error overriding none");
        }
    }
    
    return;
}

// Audio Session helpers
- (BOOL)initializeAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayAndRecord
          //withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker /*AVAudioSessionCategoryOptionMixWithOthers*/
                        error:&error]) {
        // handle error
        RCLogError("Error setting AVAudioSession category");
        return NO;
    }
    
    if (![session setActive:YES error:&error]) {
        RCLogError("Error activating audio session");
        return NO;
    }
    return YES;
}

- (BOOL)finalizeAudioSession
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone
                                    error:&error]) {
        RCLogError("Error overriding output to none");
        return NO;
    }

    if (![session setActive:NO error:&error]) {
        RCLogError("Error activating audio session");
        return NO;
    }
    
    return YES;
}

@end
