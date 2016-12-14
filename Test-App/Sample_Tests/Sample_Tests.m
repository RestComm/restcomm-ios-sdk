//
//  Sample_Tests.m
//  Sample_Tests
//
//  Created by Antonis Tsakiridis on 10/26/16.
//  Copyright © 2016 Telestax Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RestCommClient.h"

@interface Sample_Tests : XCTestCase<RCDeviceDelegate, RCConnectionDelegate> {
    
@private
    // add instance variables to the CalcTests class
    RCDevice * device;
    //RCConnection * connection;
    //NSMutableDictionary * parameters;
    //BOOL isInitialized;
    //BOOL isRegistered;
    NSString * username;
    NSString * password;
    NSString * restcommUrl;
    
    XCTestExpectation *genericExpectation;
}
@end

@implementation Sample_Tests

// Global setUp
+ (void)setUp {
    NSLog(@"-- Global setUp");
}

// Global tearDown
+ (void)tearDown {
    NSLog(@"-- Global tearDown");
}

// Test-level setUp
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    //isRegistered = NO;
    //isInitialized = NO;
    
    
    restcommUrl = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"RESTCOMM_URL"];
    username = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"RESTCOMM_USERNAME"];
    password = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"RESTCOMM_PASSWORD"];

    NSLog(@"---------- Starting Test");
}

// Test-level tearDown
- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


// ---------- Actual tests
- (void)testSuccessfulRegistration {
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                  username, @"aor",
                  password, @"password",
                  restcommUrl, @"registrar",
                  nil];
    device = [[RCDevice alloc] initWithParams:parameters delegate:self];
    
    // Create an expectation object. Remember it's possible to wait on multiple expectations.
    genericExpectation = [self expectationWithDescription:@"Send Register request"];
    
    // The test will pause here, running the run loop, until the timeout is hit or all expectations are fulfilled.
    [self waitForExpectationsWithTimeout:10.0 handler:^(NSError *error) {
        [device unlisten];
    }];
}

/**/
- (void)testFaildRegistrationInvalidPassword {
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                        username, @"aor",
                                        @"invalid-password", @"password",
                                        restcommUrl, @"registrar",
                                        nil];
    device = [[RCDevice alloc] initWithParams:parameters delegate:self];
    
    // Create an expectation object. Remember it's possible to wait on multiple expectations.
    genericExpectation = [self expectationWithDescription:@"Send Register request"];
    
    // The test will pause here, running the run loop, until the timeout is hit or all expectations are fulfilled.
    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        [device unlisten];
    }];
}

// Not ready yet, we're getting runtime issue with the simulator
- (void)DISABLED_testSuccessfulCall {
    // 1. register with Restcomm
    NSLog(@"-- Registering");
    NSMutableDictionary * parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                        username, @"aor",
                                        password, @"password",
                                        restcommUrl, @"registrar",
                                        nil];
    device = [[RCDevice alloc] initWithParams:parameters delegate:self];
    
    // Create an expectation object. Remember it's possible to wait on multiple expectations.
    genericExpectation = [self expectationWithDescription:@"Send Register request"];
    
    // The test will pause here, running the run loop, until the timeout is hit or all expectations are fulfilled.
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        //[device unlisten];
        NSLog(@"-- Registered");
    }];
    
    
    // 2. Make a call and once connected disconnect
    // which is the Hello World RestComm Application). Also set the ip address for your RestComm instance
    NSLog(@"-- Calling");
    [parameters setObject:@"+1235" forKey:@"username"];
    
    // call the other party
    RCConnection * connection = [device connect:parameters delegate:self];
    genericExpectation = [self expectationWithDescription:@"Make a call to +1235"];
    [self waitForExpectationsWithTimeout:20.0 handler:^(NSError *error) {
        NSLog(@"-- Disconnect");
        [connection disconnect];
    }];

    // 3. Once the call is disconnected shut down device
    NSLog(@"-- Disconnected");
    genericExpectation = [self expectationWithDescription:@"Waiting to disconnect call"];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
        NSLog(@"-- Shutting down");
        [device unlisten];
    }];
}

/*
- (void)testDebugTimeout {
    NSLog(@"==================== Calling debugCompletion");
    XCTestExpectation *expectation = [self expectationWithDescription:@"Test expectation"];
    [self debugCompletion:^{
        NSLog(@"==================== Completion called");
        XCTAssert(true);
        [expectation fulfill];
    }];
    
    NSLog(@"==================== Calling waitForExpectationsWithTimeout");
    // The test will pause here, running the run loop, until the timeout is hit or all expectations are fulfilled.
    [self waitForExpectationsWithTimeout:3.0 handler:^(NSError *error) {
        NSLog(@"==================== Finished");
    }];
    NSLog(@"==================== After waitForExpectationsWithTimeout");
}
 */

// ---------- Delegate methods for RC Device
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    NSLog(@"-- deviceDidStartListeningForIncomingConnections");
    
    if ([self.name rangeOfString:@"testSuccessfulRegistration"].location != NSNotFound) {
        XCTAssert(true);
        [genericExpectation fulfill];
        //genericExpectation = nil;
    }
    if ([self.name rangeOfString:@"testSuccessfulCall"].location != NSNotFound) {
        XCTAssert(true);
        [genericExpectation fulfill];
        //genericExpectation = nil;
    }

}

- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    NSLog(@"-- didStopListeningForIncomingConnections, code: %ld, text: %@, test-name: %@", error.code, error.description, self.name);
    
    // test-name: -[Sample_Tests testSuccessfulRegistration]
    if ([self.name rangeOfString:@"testSuccessfulRegistration"].location != NSNotFound) {
        
    }

    if ([self.name rangeOfString:@"testFaildRegistrationInvalidPassword"].location != NSNotFound) {
        // Successful if we got authentication error
        if (error.code == ERROR_REGISTER_AUTHENTICATION) {
            XCTAssert(true);
        }
        else {
            XCTAssert(false);
        }
        [genericExpectation fulfill];
    }
    if ([self.name rangeOfString:@"testSuccessfulCall"].location != NSNotFound) {
        // Successful if we got authentication error
        if (error.code == RESTCOMM_CLIENT_SUCCESS) {
            XCTAssert(true);
        }
        else {
            XCTAssert(false);
        }
        [genericExpectation fulfill];
    }

}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message withParams:(NSDictionary *)params
{
}

// 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
}

// not implemented yet
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

// ---------- Delegate methods for RC Connection
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error
{
    
}

// optional
// 'ringing' for outgoing connections
- (void)connectionDidStartConnecting:(RCConnection*)connection
{
    //self.statusLabel.text = @"Did start connecting";
}

- (void)connectionDidConnect:(RCConnection*)connection
{
    //self.statusLabel.text = @"Connected";
    if ([self.name rangeOfString:@"testSuccessfulCall"].location != NSNotFound) {
        //XCTAssert(true);
        //[genericExpectation fulfill];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"-- Calling dispatch_after body");
            XCTAssert(true);
            [genericExpectation fulfill];
        });
    }

}

- (void)connectionDidDisconnect:(RCConnection*)connection
{
    if ([self.name rangeOfString:@"testSuccessfulCall"].location != NSNotFound) {
        NSLog(@"-- connectionDidDisconnect");
        XCTAssert(true);
        [genericExpectation fulfill];
    }

}

- (void)connectionDidCancel:(RCConnection *)connection
{
    
}

- (void)connectionDidGetDeclined:(RCConnection *)connection
{
    
}

- (void)connection:(RCConnection *)connection didReceiveLocalVideo:(RTCVideoTrack *)localVideoTrack
{
    
}

- (void)connection:(RCConnection *)connection didReceiveRemoteVideo:(RTCVideoTrack *)remoteVideoTrack
{
    
}

/*
- (void)debugCompletion:(void (^)(void))completionBlock
{
    NSLog(@"==================== debugCompletion");
 
    //[self performSelector:@selector(asyncCall) withObject:nil afterDelay:5.0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"==================== Calling completion block");
        completionBlock();
    });
}
 */

/*
- (void)asyncCall:(void (^)(void))completionBlock
{
    NSLog(@"==================== Calling completion block");
    completionBlock();
}
- (void)asyncCall
{
    NSLog(@"==================== Calling completion block");
    //completionBlock();
}
 */


@end
