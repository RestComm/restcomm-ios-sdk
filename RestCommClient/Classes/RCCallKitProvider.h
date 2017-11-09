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

#import <CallKit/CXCall.h>
#import <CallKit/CallKit.h>
#import "RCConnection.h"

@protocol RCCallKitProviderDelegate
/**
 *  @abstract newIncomingCallAnswered is called when call needs to be handled by the app
 *  @param connection The RCConnection instance
 */
- (void)newIncomingCallAnswered:(RCConnection *)connection;

/*
 *  Will be called when call is Ended from Callkit (locked phone mode)
 */
- (void)callEnded;
@end

/**
 *  @abstract RCCallKitProvider handles the CallKit logic.
 */
@interface RCCallKitProvider : NSObject <CXProviderDelegate, RCConnectionDelegate>

@property (nonatomic, strong) RCConnection * connection;

/**
 *  @abstract Initialize a new instance
 *  @param delegate The RCCallKitProviderDelegate delegate instance
 *  @param imageName Resource's image name which will be shown on callkit view
 *  The icon image should be a square with side length of 40 points.
 *  The alpha channel of the image is used to create a white image mask,
 *  which is used in the system native in-call UI for the button which takes
 *  the user from this system UI to the 3rd-party app.
 */
- (id)initWithDelegate:(id<RCCallKitProviderDelegate>)delegate andImage:(NSString *)imageName;

/**
 *  @abstract It will present the callkit layout for incoming call and report the call to callkit
 *  @param isVideo YES if its a video call, NO otherwise
 */
- (void)presentIncomingCallWithVideo:(BOOL)isVideo;

/**
 *  @abstract Reports connecting to the callkit
 */
- (void)reportConnecting;

/**
 *  @abstract Reports connected state of the call to callkit
 */
- (void)reportConnected;

/**
 *  @abstract Reports start call to callkit
 *  @param isVideo YES if its a video call, NO otherwise
 */
- (void)startCall:(NSString *)handle isVideo:(BOOL)isVideo;

/**
 *  @abstract Reports end call to callkit
 */
- (void)endCall;

@end
