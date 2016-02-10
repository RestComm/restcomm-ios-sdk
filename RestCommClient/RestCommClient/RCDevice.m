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
#import "RCDevice.h"
#import "RCConnection.h"
#import "RCConnectionDelegate.h"
#import "SipManager.h"
#import "Reachability.h"
#import "RCDeviceDelegate.h"
#import <AVFoundation/AVFoundation.h>   // sounds

#include "common.h"
#include "Utilities.h"

@interface RCDevice ()
// private stuff
// TODO: move this to separate module
@property (readwrite) NSMutableData * httpData;
// make it read-write internally
@property (nonatomic, readwrite) NSDictionary* capabilities;
@property SipManager * sipManager;
// notice that owner of the connection is the App, not us
@property RCConnection * currentConnection;
@property AVAudioPlayer * messagePlayer;

// reachability
@property Reachability* internetReachable;
@property Reachability* hostReachable;
@property NetworkStatus reachabilityStatus;
@property BOOL hostActive;
@end


@implementation RCDevice

NSString* const RCDeviceCapabilityIncomingKey = @"RCDeviceCapabilityIncomingKey";
NSString* const RCDeviceCapabilityOutgoingKey = @"RCDeviceCapabilityOutgoingKey";
NSString* const RCDeviceCapabilityExpirationKey = @"RCDeviceCapabilityExpirationKey";
NSString* const RCDeviceCapabilityAccountSIDKey = @"RCDeviceCapabilityAccountSIDKey";
NSString* const RCDeviceCapabilityApplicationSIDKey = @"RCDeviceCapabilityApplicationSIDKey";
NSString* const RCDeviceCapabilityApplicationParametersKey = @"RCDeviceCapabilityApplicationParametersKey";
NSString* const RCDeviceCapabilityClientNameKey = @"RCDeviceCapabilityClientNameKey";

- (void) populateCapabilitiesFromToken:(NSString*)capabilityToken
{
    // TODO: do proper population from the actual token (currently we are using hard-coded values to test
    /*
    NSNumber * expiration = [NSNumber numberWithLongLong:((long long)[[NSDate date] timeIntervalSince1970] + 3600)];
    self.capabilities = [NSDictionary dictionaryWithObjectsAndKeys:
                         expiration, RCDeviceCapabilityExpirationKey,
                         @1, RCDeviceCapabilityOutgoingKey,
                         @1, RCDeviceCapabilityIncomingKey,
                         nil];
     */
    //[self.capabilities setValue:expiration forKey:@"expiration"];
}

- (id)initWithParams:(NSDictionary*)parameters delegate:(id<RCDeviceDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.capabilities = nil;
        self.incomingSoundEnabled = YES;
        self.outgoingSoundEnabled = YES;
        self.disconnectSoundEnabled = NO;
        self.currentConnection = nil;
        // readonly, so no setter
        _state = RCDeviceStateOffline;
        
        [self prepareSounds];
        
        // init logging + set logging level
        [[RestCommClient sharedInstance] setLogLevel:RC_LOG_DEBUG];
        RCLogNotice("[RCDevice initWithParams]");

        // reachability
        self.reachabilityStatus = NotReachable;
        self.hostActive = NO;
        // check for internet connection
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkNetworkStatus:) name:kReachabilityChangedNotification object:nil];
        // internet connection
        _internetReachable = [Reachability reachabilityForInternetConnection];
        [_internetReachable startNotifier];
        // check if a pathway to a random host exists
        _hostReachable = [Reachability reachabilityWithHostName:@"www.google.com"];
        [_hostReachable startNotifier];
        self.reachabilityStatus = [_internetReachable currentReachabilityStatus];
        
        self.sipManager = [[SipManager alloc] initWithDelegate:self andParams:parameters];

        if (self.reachabilityStatus != NotReachable) {
            if (![parameters objectForKey:@"registrar"] ||
                ([parameters objectForKey:@"registrar"] && [[parameters objectForKey:@"registrar"] length] == 0)) {
                // registraless; we can transition to ready right away (i.e. without waiting for Restcomm to reply to REGISTER)
                _state = RCDeviceStateReady;
            }
            // start signalling eventLoop (i.e. Sofia)
            [self.sipManager eventLoop];
        }

    }
    
    return self;
}

- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate
{
    RCLogNotice("[RCDevice initWithCapabilityToken:delegate:] is not supported yet; using default configuration values. To do your own configuration please use [RCDevice initWithParams:delegate:]");
    
    [self populateCapabilitiesFromToken:capabilityToken];

    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:@"sip:bob@telestax.com", @"aor",
                             @"sip:23.23.228.238:5080", @"registrar",
                             @"1234", @"password", nil];

    return [self initWithParams:params delegate:delegate];
}

- (void)dealloc
{
    RCLogNotice("[RCDevice dealloc]");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)listen
{
    RCLogNotice("[RCDevice listen], state: %d", _state);
    if (_state == RCDeviceStateOffline) {
        NetworkStatus status = [_internetReachable currentReachabilityStatus];
        if (self.reachabilityStatus != NotReachable) {
            // we are reachable

            // start signalling eventLoop (i.e. Sofia)
            [self.sipManager eventLoop];

            if (![self.sipManager.params objectForKey:@"registrar"] ||
                ([self.sipManager.params objectForKey:@"registrar"] && [[self.sipManager.params objectForKey:@"registrar"] length] == 0)) {
                // registraless; we can transition to ready right away (i.e. without waiting for Restcomm to reply to REGISTER)
                _state = RCDeviceStateReady;
            }
            
            if (status != self.reachabilityStatus) {
                // reachability status changed, notify application
                RCLogNotice("[RCDevice listen] Reachability state has changed from: %d to: %d", self.reachabilityStatus, status);
                [self.delegate device:self didReceiveConnectivityUpdate:(RCConnectivityStatus)status];
                self.reachabilityStatus = status;
            }
            [self.delegate deviceDidStartListeningForIncomingConnections:self];
        }
        else {
            RCLogError("[RCDevice listen] No internet connectivity");
        }
    }
    else if (_state == RCDeviceStateReady) {
        [self.sipManager updateParams:nil];
        [self.delegate deviceDidStartListeningForIncomingConnections:self];
    }
}

- (void)unlisten
{
    RCLogNotice("[RCDevice unlisten], state: %d", _state);
    if (_state != RCDeviceStateOffline) {
        if (_state == RCDeviceStateBusy) {
            [self disconnectAll];
        }

        [self.sipManager unregister:nil];
        [self.sipManager shutdown:NO];
        _state = RCDeviceStateOffline;
        [self.delegate device:self didStopListeningForIncomingConnections:nil];
    }
}

- (void)updateCapabilityToken:(NSString*)capabilityToken
{
    RCLogNotice("[RCDevice updateCapabilityToken]");
}

- (NSDictionary*)getParams
{
    return [self.sipManager params];
}

- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;
{
    RCLogNotice("[RCDevice connect: %s]", [[Utilities stringifyDictionary:parameters] UTF8String]);
    if (_state != RCDeviceStateReady) {
        if (_state == RCDeviceStateBusy) {
            RCLogError("Error connecting: RCDevice is busy");
        }
        else if (_state == RCDeviceStateOffline) {
            RCLogError("Error connecting: RCDevice is offline; consider calling [RCDevice listen]");
        }
        return nil;
    }
    self.currentConnection = [[RCConnection alloc] initWithDelegate:(id<RCConnectionDelegate>)delegate
                                                          andDevice:(RCDevice*)self
                                                      andSipManager:self.sipManager
                                                        andIncoming:false
                                                           andState:RCConnectionStatePending
                                                      andParameters:nil];

    self.sipManager.connectionDelegate = self.currentConnection;
    _state = RCDeviceStateBusy;
    BOOL videoAllowed = NO;
    if ([parameters objectForKey:@"video-enabled"]) {
        videoAllowed = [[parameters objectForKey:@"video-enabled"] boolValue];
    };
    // make a call to whoever parameters designate
    if (![self.sipManager invite:[parameters objectForKey:@"username"] withVideo:videoAllowed customHeaders:[parameters objectForKey:@"sip-headers"]]) {
        RCLogError("Error connecting: connection already ongoing");
        return nil;
    }

    return self.currentConnection;
}

//- (void)sendMessage:(NSString*)message to:(NSDictionary*)parameters
- (BOOL)sendMessage:(NSDictionary*)parameters
{
    RCLogNotice("[RCDevice message: %s\nto: %s]", [[parameters objectForKey:@"message"] UTF8String], [[Utilities stringifyDictionary:parameters] UTF8String]);
    if (_state == RCDeviceStateOffline) {
        NSLog(@"Error connecting: RCDevice is offline; consider calling [RCDevice listen]");
        return NO;
    }

    //NSString* uri = [NSString stringWithFormat:[parameters objectForKey:@"uas-uri-template"], [parameters objectForKey:@"username"]];
    [self.sipManager message:[parameters objectForKey:@"message"] to:[parameters objectForKey:@"username"] customHeaders:[parameters objectForKey:@"sip-headers"]];
    return YES;
}


- (void)setOutgoingSoundEnabled:(BOOL)outgoingSoundEnabled
{
    RCLogNotice("[RCDevice setOutgoingSoundEnabled");
    _outgoingSoundEnabled = outgoingSoundEnabled;
}

- (void)setIncomingSoundEnabled:(BOOL)incomingSoundEnabled
{
    RCLogNotice("[RCDevice setIncomingSoundEnabled");
    _incomingSoundEnabled = incomingSoundEnabled;
}

- (void)setDisconnectSoundEnabled:(BOOL)disconnectSoundEnabled
{
    RCLogNotice("[RCDevice setDisconnectSoundEnabled");
    _disconnectSoundEnabled = disconnectSoundEnabled;
}

- (void)disconnectAll
{
    RCLogNotice("[RCDevice disconnectAll], state: %d", _state);
    if (_state == RCDeviceStateBusy) {
        [self.currentConnection disconnect];
        _state = RCDeviceStateReady;
    }
}

// returns YES if an actual registration was sent (the App can use that to properly convey state to the user
- (BOOL) updateParams:(NSDictionary*)params
{
    RCLogNotice("[RCDevice updateParams]");

    if (self.reachabilityStatus != NotReachable) {
        if ([self.sipManager updateParams:params]) {
            // if a REGISTER was sent update state to offline, cause we need a 200 OK to the registration to consider ourselves truly online
            _state = RCDeviceStateOffline;
            return YES;
        }
    }
    return NO;
}

#pragma mark SipManager Delegate methods
- (void)sipManager:(SipManager *)sipManager didReceiveMessageWithData:(NSString *)message from:(NSString *)from
{
    RCLogNotice("[RCDevice didReceiveMessageWithData: %s\nfrom: %s]", [message UTF8String], [from UTF8String]);
    if (self.incomingSoundEnabled == true) {
        [self.messagePlayer play];
    }
    [self.delegate device:self didReceiveIncomingMessage:message withParams:[NSDictionary dictionaryWithObject:from forKey:@"from"]];
}

- (void)sipManagerDidReceiveCall:(SipManager *)sipManager from:(NSString*)from
{
    RCLogNotice("[RCDevice sipManagerDidReceiveCall]");
    self.currentConnection = [[RCConnection alloc] initWithDelegate:(id<RCConnectionDelegate>)self.delegate
                                                          andDevice:(RCDevice*)self
                                                      andSipManager:self.sipManager
                                                        andIncoming:true
                                                           andState:RCConnectionStateConnecting
                                                      andParameters:[NSDictionary dictionaryWithObject:from forKey:@"from"]];

    self.sipManager.connectionDelegate = self.currentConnection;
    _state = RCDeviceStateBusy;
    [self.currentConnection incomingRinging];
    
    // TODO: passing nil on the connection for now
    [self.delegate device:self didReceiveIncomingConnection:self.currentConnection];
}

- (void)sipManagerDidInitializedSignalling:(SipManager *)sipManager
{
    RCLogNotice("[RCDevice sipManagerDidInitializedSignalling]");

    [self.delegate deviceDidInitializeSignaling:self];
    [self.delegate deviceDidStartListeningForIncomingConnections:self];
}

- (void)sipManager:(SipManager*)sipManager didSignallingError:(NSError *)error
{
    RCLogNotice("[RCDevice didSignallingError: %s]", [[Utilities stringifyDictionary:[error userInfo]] UTF8String]);
    if (error.code == ERROR_REGISTERING_GENERIC || error.code == ERROR_REGISTERING_TIMEOUT) {
        [self.delegate device:self didReceiveConnectivityUpdate:RCConnectivityStatusNone];
        _state = RCDeviceStateOffline;
    }
    if (error.code == ERROR_REGISTERING_AUTHENTICATION) {
        [self.delegate device:self didReceiveConnectivityUpdate:RCConnectivityStatusNone];
        _state = RCDeviceStateOffline;
        
        [self.delegate device:self didStopListeningForIncomingConnections:error];
        /*
        [self.delegate device:self didStopListeningForIncomingConnections:[[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                                                                     code:ERROR_REGISTERING_AUTHENTICATION
                                                                                                 userInfo:@{NSLocalizedDescriptionKey : [RestCommClient getErrorText:(int)error.code]}]];
         */
    }
}

- (void)sipManagerDidRegisterSuccessfully:(SipManager *)sipManager
{
    if (_state == RCDeviceStateOffline) {
        _state = RCDeviceStateReady;
        [self.delegate device:self didReceiveConnectivityUpdate:(RCConnectivityStatus)self.reachabilityStatus];
    }
}

- (void)sipManagerWillUnregister:(SipManager *)sipManager
{
    // Note: there are times where unregister is triggered not by a direct application action
    // (for example when updateParams() is called with a new registrar). In those cases we need
    // to notify the application that we transition to offline
    //_state = RCDeviceStateOffline;
    //[self.delegate device:self didReceiveConnectivityUpdate:RCConnectivityStatusNone];
}

#pragma mark Helpers
- (void)prepareSounds
{
    // message
    NSString * filename = @"message.mp3";
    // we are assuming the extension will always be the last 3 letters of the filename
    NSString * file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                                      ofType:[filename substringFromIndex:[filename length] - 3]];
    if (file != nil) {
        NSError *error;
        self.messagePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
        if (!self.messagePlayer) {
            NSLog(@"Error: %@", [error description]);
            return;
        }
    }
}

// called after network status changes
- (void)checkNetworkStatus:(NSNotification *)notice
{
    NetworkStatus newStatus = [_internetReachable currentReachabilityStatus];
    RCLogNotice("[RCDevice checkNetworkStatus] Reachability update: %d", (int)newStatus);
    
    if (newStatus == NotReachable && _state != RCDeviceStateOffline) {
        RCLogNotice("[RCDevice checkNetworkStatus] action: no connectivity");
        [self.sipManager shutdown:NO];
        _state = RCDeviceStateOffline;
        self.reachabilityStatus = newStatus;
        [self.delegate device:self didReceiveConnectivityUpdate:(RCConnectivityStatus)newStatus];
        return;
    }
    
    if ((self.reachabilityStatus == ReachableViaWiFi && newStatus == ReachableViaWWAN) ||
        (self.reachabilityStatus == ReachableViaWWAN && newStatus == ReachableViaWiFi)) {
        if (_state != RCDeviceStateOffline) {
            RCLogNotice("[RCDevice checkNetworkStatus] action: switch between wifi and mobile");
            [self.sipManager shutdown:YES];
            self.reachabilityStatus = newStatus;
            [self.delegate device:self didReceiveConnectivityUpdate:(RCConnectivityStatus)newStatus];
            return;
        }
    }
    
    if ((newStatus == ReachableViaWiFi || newStatus == ReachableViaWWAN) &&
        _state == RCDeviceStateOffline) {
        RCLogNotice("[RCDevice checkNetworkStatus] action: wifi/mobile available");
        [self.sipManager eventLoop];
        self.reachabilityStatus = newStatus;
        if (![self.sipManager.params objectForKey:@"registrar"] ||
            ([self.sipManager.params objectForKey:@"registrar"] && [[self.sipManager.params objectForKey:@"registrar"] length] == 0)) {
            // registraless; we can transition to ready right away (i.e. without waiting for Restcomm to reply to REGISTER)
            _state = RCDeviceStateReady;
            [self.delegate device:self didReceiveConnectivityUpdate:(RCConnectivityStatus)newStatus];
        }
    }
    
    /*
    NetworkStatus hostStatus = [_hostReachable currentReachabilityStatus];
    switch (hostStatus)
    {
        case NotReachable:
        {
            NSLog(@"A gateway to the host server is down.");
            self.hostActive = NO;
            
            break;
        }
        case ReachableViaWiFi:
        {
            NSLog(@"A gateway to the host server is working via WIFI.");
            self.hostActive = YES;
            
            break;
        }
        case ReachableViaWWAN:
        {
            NSLog(@"A gateway to the host server is working via WWAN.");
            self.hostActive = YES;
            
            break;
        }
    }
     */
}

// TODO: leave this around because at some point we might add REST functionality on the client
/*
#pragma mark HTTP related methods (internal)
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // A response has been received, this is where we initialize the instance var you created
    // so that we can append data to it in the didReceiveData method
    // Furthermore, this method is called each time there is a redirect so reinitializing it
    // also serves to clear it
    NSLog(@"HTTP start");

    
    self.httpData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    // append the new data to the instance variable you declared
    NSLog(@"HTTP append");

    [self.httpData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Return nil to indicate not necessary to store a cached response for this connection
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // The request is complete and data has been received
    // You can parse the stuff in your instance variable now
    NSLog(@"HTTP finished");
    NSLog(@"HTTP data: %@", [[NSString alloc] initWithData:self.httpData encoding:NSUTF8StringEncoding]);  //[self.httpData );
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // The request has failed for some reason!
    // Check the error var
    NSLog(@"HTTP error");
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge previousFailureCount] == 0) {
        NSLog(@"HTTP - received authentication challenge");
        NSURLCredential *newCredential = [NSURLCredential credentialWithUser:@"administrator@company.com"
                                                                    password:@"el@m0ynte"
                                                                 persistence:NSURLCredentialPersistenceForSession];
        NSLog(@"HTTP - credential created");
        [[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
        NSLog(@"HTTP - responded to authentication challenge");
    }
    else {
        NSLog(@"HTTP - previous authentication failure");
    }
}

-(void)dial
{
    
    // Create the request.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://192.168.2.5:8080/restcomm/2012-04-24/Accounts/ACae6e420f425248d6a26948c17a9e2acf/Calls.json"]];
    
    // Specify that it will be a POST request
    request.HTTPMethod = @"POST";
    
    // This is how we set header fields
    //[request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    
    // Convert your data and set your request's HTTPBody property
    NSString *postData = @"From=alice&To=client:bob&Url=http://192.168.2.5:8080/restcomm/demos/dial/client/dial-client.xml";
    NSData *requestBodyData = [postData dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = requestBodyData;
    // Create url connection and fire request
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}
*/

@end
