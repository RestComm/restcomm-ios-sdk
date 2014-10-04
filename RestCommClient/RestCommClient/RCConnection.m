//
//  RCConnection.m
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import "RCConnection.h"
#import "SipManager.h"

@interface RCConnection ()
// private methods
// which device owns this connection
@end

@implementation RCConnection
@synthesize state;
/* RCConnection needs to notify its delegate for the following events:
 *
 * @required
 * - (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error;
 *
 * @optional
 * - (void)connectionDidStartConnecting:(RCConnection*)connection;
 * - (void)connectionDidConnect:(RCConnection*)connection;
 * - (void)connectionDidDisconnect:(RCConnection*)connection;
 */

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

/*
- (void)incomingRinging:(SipManager *)sipManager
{
    [self.delegate connectionDidStartConnecting:self];
    [self setState:RCConnectionStateConnecting];
}

- (void)incomingEstablished:(SipManager *)sipManager
{
    [self.delegate connectionDidConnect:self];
    [self setState:RCConnectionStateConnected];
}
*/
@end
