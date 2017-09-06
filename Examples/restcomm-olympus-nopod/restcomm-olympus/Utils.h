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
#import "LocalContact.h"

extern NSString* const RestCommClientSDKLatestGitHash;

@interface Utils : NSObject
+ (void) setupUserDefaults;
+ (LocalContact *)contactForIndex:(int)index;
//+ (int)indexForContact:(NSString*)alias;
// if contact is not found returns -1
+ (NSString*)sipUri2Alias:(NSString*)sipUri;
+ (int)indexForContact:(NSString*)sipUri;
+ (int)contactCount;
+ (void)addContact:(LocalContact *)contact;
+ (void)removeContactAtIndex:(int)index;
+ (void)updateContactWithSipUri:(NSString*)sipUri alias:(NSString*)alias;
+ (NSString*)sipIdentification;
+ (NSString*)sipPassword;
+ (NSString*)sipRegistrar;
+ (BOOL)turnEnabled;
+ (NSString*)turnUrl;
+ (NSString*)turnUsername;
+ (NSString*)turnPassword;
+ (NSString*)turnCandidateTimeout;
+ (BOOL)isFirstTime;
+ (NSString*)pendingInterappUri;
+ (BOOL)signalingSecure;

+ (void)updateSipIdentification:(NSString*)sipIdentification;
+ (void)updateSipPassword:(NSString*)sipPassword;
+ (void)updateSipRegistrar:(NSString*)sipRegistrar;
+ (void)updateTurnEnabled:(BOOL)turnEnabled;
+ (void)updateTurnUrl:(NSString*)turnUrl;
+ (void)updateTurnUsername:(NSString*)turnUsername;
+ (void)updateTurnPassword:(NSString*)turnPassword;
+ (void)updateTurnCandidateTimeout:(NSString*)turnCandidateTimeout;
+ (void)updateIsFirstTime:(BOOL)isFirstTime;
+ (void)updatePendingInterappUri:(NSString*)uri;
+ (void)updateSignalingSecure:(BOOL)signalingSecure;
// return messages in the format understood by MessageTableViewController
+ (NSArray*)messagesForSipUri:(NSString*)sipUri;
+ (void)addMessageForSipUri:(NSString*)sipUri text:(NSString*)text type:(NSString*)type;
+ (NSString*)convertInterappUri2RestcommUri:(NSURL*)uri;
@end
