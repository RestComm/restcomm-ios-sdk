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

#import "RCConnection.h"
#import "RCConnectionDelegate.h"
#import "RCDevice.h"
#import "RCDeviceDelegate.h"
#import "RCPresenceEvent.h"

#import <Foundation/Foundation.h>

@interface RestCommClient : NSObject

typedef enum {
    RC_LOG_EMERG,
    RC_LOG_ALERT,
    RC_LOG_CRIT,
    RC_LOG_ERROR,
    RC_LOG_WARN,
    RC_LOG_NOTICE,
    RC_LOG_INFO,
    RC_LOG_DEBUG,
} RCLogLevel;

typedef enum {
    ERROR_WEBRTC_SDP,
    ERROR_WEBRTC_ICE,
    ERROR_WEBRTC_ALREADY_INITIALIZED,
    ERROR_CALLING_GENERIC,
    ERROR_CALLING_NOT_FOUND,
    ERROR_CALLING_AUTHENTICATION,
    ERROR_CALLING_TIMEOUT,
    ERROR_TEXT_MESSAGING_GENERIC,
    ERROR_TEXT_MESSAGING_NOT_FOUND,
    ERROR_TEXT_MESSAGING_AUTHENTICATION,
    ERROR_TEXT_MESSAGING_TIMEOUT,
    ERROR_REGISTERING_GENERIC,
    ERROR_REGISTERING_AUTHENTICATION,
    ERROR_REGISTERING_TIMEOUT,
    ERROR_SENDING_DIGITS,
    ERROR_CODES_MAX,
} errorCodes;

@property NSString * errorDomain;
@property NSDictionary * errors;
// Restcomm SDK version
@property NSString * version;

+ (id)sharedInstance;
- (void) setLogLevel:(RCLogLevel)level;
+ (NSString*)getErrorText:(int)errorCode;


@end
