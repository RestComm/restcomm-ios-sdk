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
#import <UIKit/UIKit.h>
#import "WebRTC/RTCVideoTrack.h"

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
 *  @abstract Incoming connection was cancelled
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidCancel:(RCConnection*)connection;

/**
 *  @abstract Connection was declined from the remote party
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidGetDeclined:(RCConnection*)connection;

/**
 *  @abstract Connection was disconnected
 *
 *  @param connection Connection of interest
 */
- (void)connectionDidDisconnect:(RCConnection*)connection;

/**
 *  @abstract Received local video track for the connection. To see the video it must be rendered inside a suitable view
 *
 *  @param connection Connection of interest
 *  @param localVideoTrack Local video track
 */
- (void)connection:(RCConnection *)connection didReceiveLocalVideo:(RTCVideoTrack *)localVideoTrack;

/**
 *  @abstract Received remote video track for the connection. To see the video it must be rendered inside a suitable view
 *
 *  @param connection Connection of interest
 *  @param remoteVideoTrack Remote video track
 */
- (void)connection:(RCConnection *)connection didReceiveRemoteVideo:(RTCVideoTrack *)remoteVideoTrack;

@end
