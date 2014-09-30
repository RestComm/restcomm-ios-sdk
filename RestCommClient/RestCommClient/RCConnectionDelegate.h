//
//  RCConnectionDelegate.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RCConnection;

@protocol RCConnectionDelegate<NSObject>

@required
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error;

@optional
- (void)connectionDidStartConnecting:(RCConnection*)connection;
- (void)connectionDidConnect:(RCConnection*)connection;
- (void)connectionDidDisconnect:(RCConnection*)connection;

@end
