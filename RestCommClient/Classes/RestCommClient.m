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

#import "RestCommClient.h"
#include "common.h"
#include <asl.h>

@implementation RestCommClient

+ (id)sharedInstance {
    static RestCommClient *sharedRestCommClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedRestCommClient = [[self alloc] init];
    });
    return sharedRestCommClient;
}

- (id)init {
    if (self = [super init]) {
        self.errorDomain = @"RestcommClient-iOS-SDK";
        self.errors = @{
                        @(RESTCOMM_CLIENT_SUCCESS) : @"Success",
                        @(ERROR_WEBRTC_SDP) : @"Webrtc media error in SDP negotiation",
                        @(ERROR_WEBRTC_ICE) : @"Webrtc media error in ICE",
                        @(ERROR_WEBRTC_TURN) : @"Error retrieving TURN servers",
                        @(ERROR_WEBRTC_ALREADY_INITIALIZED) : @"Webrtc media already initialized",
                        @(ERROR_MEDIA_PERMISSION_DENIED) : @"Permission denied for microphone/camera",
                        @(ERROR_CALL_GENERIC) : @"Generic call error",
                        @(ERROR_CALL_NOT_FOUND) : @"Called party not found",
                        @(ERROR_CALL_AUTHENTICATION) : @"Error authenticating user for the call",
                        @(ERROR_CALL_TIMEOUT) : @"Call timed out",
                        @(ERROR_CALL_URI_INVALID) : @"Called party URI is invalid",
                        @(ERROR_CALL_SERVICE_UNAVAILABLE) : @"Call failed due to service being unavailable",
                        @(ERROR_TEXT_MESSAGE_GENERIC) : @"Text message generic error",
                        @(ERROR_TEXT_MESSAGE_NOT_FOUND) : @"Text message error:recipient not found",
                        @(ERROR_TEXT_MESSAGE_AUTHENTICATION) : @"Error authenticating user for text message",
                        @(ERROR_TEXT_MESSAGE_TIMEOUT) : @"Text message timed out",
                        @(ERROR_TEXT_MESSAGE_URI_INVALID) : @"Text message recipient URI is invalid",
                        @(ERROR_TEXT_MESSAGE_SERVICE_UNAVAILABLE) : @"Text message failed due to service being unavailable",
                        @(ERROR_REGISTER_GENERIC) : @"Registration generic error",
                        @(ERROR_REGISTER_AUTHENTICATION) : @"Error authenticating with Restcomm",
                        @(ERROR_REGISTER_SERVICE_UNAVAILABLE) : @"Error connecting to Restcomm: service unavailable",
                        @(ERROR_REGISTER_TIMEOUT) : @"Registration with Restcomm timed out",
                        @(ERROR_REGISTER_URI_INVALID) : @"Register URI is invalid",
                        @(ERROR_SENDING_DIGITS) : @"Error sending DTMF Digits",
                        @(ERROR_LOST_CONNECTIVITY) : @"Lost connectivity with Restcomm",
                        @(ERROR_INITIALIZING_SIGNALING) : @"Error initializing signaling: no valid network interface to bind to",
                        @(ERROR_SECURE_SIGNALLING) : @"Error setting up secure signaling",

                        };
        initializeLogging();
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

- (void) setLogLevel:(RCLogLevel)level
{
    int aslLevel = 0;
    if (level == RC_LOG_EMERG) {
        aslLevel = ASL_LEVEL_EMERG;
    }
    else if (level == RC_LOG_ALERT) {
        aslLevel = ASL_LEVEL_ALERT;
    }
    else if (level == RC_LOG_CRIT) {
        aslLevel = ASL_LEVEL_CRIT;
    }
    else if (level == RC_LOG_ERROR) {
        aslLevel = ASL_LEVEL_ERR;
    }
    else if (level == RC_LOG_WARN) {
        aslLevel = ASL_LEVEL_WARNING;
    }
    else if (level == RC_LOG_NOTICE) {
        aslLevel = ASL_LEVEL_NOTICE;
    }
    else if (level == RC_LOG_INFO) {
        aslLevel = ASL_LEVEL_INFO;
    }
    else if (level == RC_LOG_DEBUG) {
        aslLevel = ASL_LEVEL_DEBUG;
    }
    
    setLogLevel(aslLevel);
}

+ (NSString*)getVersion
{
    return [NSString stringWithUTF8String:SIP_USER_AGENT];
}

+ (NSString*)getErrorText:(int)errorCode
{
    RestCommClient * restCommClient = [RestCommClient sharedInstance];
    return [restCommClient.errors objectForKey:[NSNumber numberWithInt:errorCode]];
}

@end
