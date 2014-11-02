//
//  RCConnectionDelegate.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

/** @file RCConnectionDelegate.h */

@class RCConnection;

/**
 *  RCConnection notifies its delegate for connection related events defined in this delegate protocol
 */
@protocol RCConnectionDelegate<NSObject>

@required
/**
 *  @abstract Emitted when a connection failed and got disconnected
 *
 *  @param connection Connection that failed
 *  @param error      Description of the error of the Connection
 */
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error;

@optional
/**
 *  @abstract Emitted when an RCConnection start to connect
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidStartConnecting:(RCConnection*)connection;

/**
 *  @abstract Connection is established
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidConnect:(RCConnection*)connection;

/**
 *  @abstract Connection was disconnected (**Not Implemented yet**)
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidDisconnect:(RCConnection*)connection;

@end
