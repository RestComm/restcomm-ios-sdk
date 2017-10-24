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

#import <Foundation/Foundation.h>
#import <CallKit/CXCall.h>
#import <CallKit/CallKit.h>
#import "RestCommClient.h"

@protocol RCCallKitProviderDelegate
/**
 *  @abstract newIncomingCallAnswered is called when call needs to be handled by the app
 *
 *  (when the app is not in inactive mode)
 *  @param connection The RCConnection instance
 */
- (void)newIncomingCallAnswered:(RCConnection *)connection;

/*
 *  Will be called when call is Ended from Callkit (locked phone mode)
 */
- (void)callEnded;
@end

@interface RCCallKitProvider : NSObject <CXProviderDelegate, RCConnectionDelegate>

@property (nonatomic, strong) RCConnection * connection;
@property (nonatomic, strong) NSUUID *currentUdid;

- (id)initWithDelegate:(id<RCCallKitProviderDelegate>)delegate;

- (void)initRCConnection:(RCConnection *)connection;

- (void)answerWithCallKit;

- (void)reportConnecting;

- (void)reportConnected;

- (void)performEndCallAction;


@end
