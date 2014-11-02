//
//  RCDevice.m
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import "RCDevice.h"
#import "RCConnection.h"
#import "RCConnectionDelegate.h"

@interface RCDevice ()
// private stuff
// TODO: move this to separate module
@property (readwrite) NSMutableData * httpData;
// make it read-write internally
@property (nonatomic, readwrite) NSDictionary* capabilities;
@property SipManager * sipManager;

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


- (id)initWithCapabilityToken:(NSString*)capabilityToken delegate:(id<RCDeviceDelegate>)delegate
{
    NSLog(@"[RCDevice initWithCapabilityToken]");
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.capabilities = nil;
        self.incomingSoundEnabled = YES;
        self.outgoingSoundEnabled = YES;
        self.disconnectSoundEnabled = NO;
        
        [self populateCapabilitiesFromToken:capabilityToken];
        
        // initialize, register and set delegate
        // TODO: fix this
        NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:@"sip:bob@telestax.com", @"aor",
                                 @"sip:192.168.2.32:5080", @"registrar", nil];
        self.sipManager = [[SipManager alloc] initWithDelegate:self andParams:params];
        [self.sipManager eventLoop];
    }
    
    return self;
}

- (void)listen
{
    NSLog(@"[RCDevice listen]");
}

- (void)unlisten
{
    NSLog(@"[RCDevice unlisten]");
    
}

- (void)updateCapabilityToken:(NSString*)capabilityToken
{
    NSLog(@"[RCDevice updateCapabilityToken]");
    
}

- (RCConnection*)connect:(NSDictionary*)parameters delegate:(id<RCConnectionDelegate>)delegate;
{
    NSLog(@"[RCDevice connect]");
    RCConnection* connection = [[RCConnection alloc] initWithDelegate:delegate];
    self.sipManager.connectionDelegate = connection;
    connection.sipManager = self.sipManager;
    connection.incoming = false;
    
    // make a call to whoever parameters designate
    //NSString* uri = [NSString stringWithFormat:[parameters objectForKey:@"uas-uri-template"], [parameters objectForKey:@"username"]];
    //NSString* uri = [NSString stringWithFormat:[parameters objectForKey:@"uas-uri-template"], [parameters objectForKey:@"username"]];
    [self.sipManager invite:[parameters objectForKey:@"username"]];

    return connection;
}

- (void)sendMessage:(NSString*)message to:(NSDictionary*)parameters
{
    //NSString* uri = [NSString stringWithFormat:[parameters objectForKey:@"uas-uri-template"], [parameters objectForKey:@"username"]];
    [self.sipManager message:message to:[parameters objectForKey:@"username"]];
}

- (void)disconnectAll
{
    NSLog(@"[RCDevice disconnectAll]");
}

#pragma mark SipManager Delegate methods
- (void)messageArrived:(SipManager *)sipManager withData:(NSString *)message
{
    [self.delegate device:self didReceiveIncomingMessage:message];
}

- (void)callArrived:(SipManager *)sipManager
{
    RCConnection * connection = [[RCConnection alloc] initWithDelegate:(id<RCConnectionDelegate>) self.delegate];
    self.sipManager.connectionDelegate = connection;
    connection.sipManager = self.sipManager;
    connection.incoming = true;
    connection.state = RCConnectionStateConnecting;
    
    // TODO: passing nil on the connection for now
    [self.delegate device:self didReceiveIncomingConnection:connection];
}

- (void) updateParams:(NSDictionary*)params
{
    [self.sipManager updateParams:params];
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
