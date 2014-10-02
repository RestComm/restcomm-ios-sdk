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
@end

@implementation RCConnection

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
    }
    return self;
}


- (void)accept
{
    NSLog(@"[RCConnection accept]");
    [self.sipManager answer];
    
}

- (void)ignore
{
    NSLog(@"[RCConnection ignore]");
   
}

- (void)reject
{
    NSLog(@"[RCConnection reject]");
    
}

- (void)disconnect
{
    NSLog(@"[RCConnection disconnect]");
    [self.sipManager bye];
}

- (void)sendDigits:(NSString*)digits
{
    NSLog(@"[RCConnection sendDigits]");
    
}

@end
