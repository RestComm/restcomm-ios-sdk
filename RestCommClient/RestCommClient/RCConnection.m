/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2014, Telestax Inc and individual contributors
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
#import "SipManager.h"

@interface RCConnection ()
// private methods
// which device owns this connection
@end

@implementation RCConnection
@synthesize state;

NSString* const RCConnectionIncomingParameterFromKey = @"RCConnectionIncomingParameterFromKey";
NSString* const RCConnectionIncomingParameterToKey = @"RCConnectionIncomingParameterToKey";
NSString* const RCConnectionIncomingParameterAccountSIDKey = @"RCConnectionIncomingParameterAccountSIDKey";
NSString* const RCConnectionIncomingParameterAPIVersionKey = @"RCConnectionIncomingParameterAPIVersionKey";
NSString* const RCConnectionIncomingParameterCallSIDKey = @"RCConnectionIncomingParameterCallSIDKey";

- (id)initWithDelegate:(id<RCConnectionDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.sipManager = nil;
        self.state = RCConnectionStateDisconnected;
        self.muted = NO;
    }
    return self;
}


- (void)accept
{
    NSLog(@"[RCConnection accept]");
    [self.sipManager answer];
    self.state = RCConnectionStateConnected;
}

- (void)ignore
{
    NSLog(@"[RCConnection ignore]");
   
}

- (void)reject
{
    NSLog(@"[RCConnection reject]");
    [self.sipManager decline];
    
}

- (void)disconnect
{
    NSLog(@"[RCConnection disconnect]");
    if (self.state == RCConnectionStateConnecting) {
        [self.sipManager cancel];
    }
    else if (self.state == RCConnectionStateConnected) {
        [self.sipManager bye];
    }
}

- (void)sendDigits:(NSString*)digits
{
    NSLog(@"[RCConnection sendDigits]");
    
}

- (void)outgoingRinging:(SipManager *)sipManager
{
    [self.delegate connectionDidStartConnecting:self];
    [self setState:RCConnectionStateConnecting];
}

- (void)outgoingEstablished:(SipManager *)sipManager
{
    [self.delegate connectionDidConnect:self];
    [self setState:RCConnectionStateConnected];
}

@end
