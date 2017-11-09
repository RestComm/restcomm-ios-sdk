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
#import "LocalMessage.h"

extern NSString* const RestCommClientSDKLatestGitHash;
extern NSString* const kFriendlyName;

@interface Utils : NSObject
+ (void) setupUserDefaults;
+ (LocalContact*)getContactForSipUri:(NSString*)sipUri;
+ (NSArray *)getSortedContacts;
+ (int)indexForContact:(NSString*)sipUri;
+ (int)contactCount;
+ (void)addContact:(LocalContact *)contact;
+ (void)removeContact:(LocalContact *)localContact;
+ (void)updateContactWithSipUri:(NSString*)sipUri forAlias:(NSString*)alias;
+ (NSString*)sipIdentification;
+ (NSString*)sipPassword;
+ (NSString*)sipRegistrar;
+ (BOOL)turnEnabled;
+ (NSString*)iceUrl;
+ (NSString*)iceUsername;
+ (NSString*)icePassword;
+ (int)iceDiscoveryType;
+ (NSString*)turnCandidateTimeout;
+ (BOOL)isFirstTime;
+ (NSString*)pendingInterappUri;
+ (BOOL)signalingSecure;

+ (void)updateSipIdentification:(NSString*)sipIdentification;
+ (void)updateSipPassword:(NSString*)sipPassword;
+ (void)updateSipRegistrar:(NSString*)sipRegistrar;
+ (void)updateTurnEnabled:(BOOL)turnEnabled;
+ (void)updateICEUrl:(NSString*)iceUrl;
+ (void)updateICEUsername:(NSString*)iceUsername;
+ (void)updateICEPassword:(NSString*)icePassword;
+ (void)updateICEDiscoveryType:(int)iceDiscoveryType;
+ (void)updateTurnCandidateTimeout:(NSString*)turnCandidateTimeout;
+ (void)updateIsFirstTime:(BOOL)isFirstTime;
+ (void)updatePendingInterappUri:(NSString*)uri;
+ (void)updateSignalingSecure:(BOOL)signalingSecure;
// return messages in the format understood by MessageTableViewController
+ (NSArray*)messagesForSipUri:(NSString*)sipUri;
+ (void)addMessage:(LocalMessage *)message;
+ (NSString*)convertInterappUri2RestcommUri:(NSURL*)uri;

+ (void)saveLastPeer:(NSString *)sipUri;
+ (NSString *)getLastPeer;

//push notifications
+ (NSString *)pushAccount;
+ (NSString *)pushPassword;
+ (NSString *)pushDomain;
+ (NSString *)pushToken;
+ (NSString *)httpDomain;

+ (BOOL)isServerEnabledForPushNotifications;
+ (BOOL)isSandbox;
+ (void)updatePushAccount:(NSString *)pushAccount;
+ (void)updatePushPassword:(NSString *)pushPassword;
+ (void)updatePushDomain:(NSString *)pushDomain;
+ (void)updatePushToken:(NSString *)pushToken;
+ (void)updateServerEnabledForPush:(BOOL)enabled;
+ (void)updateIsSandboxPush:(BOOL)enabled;
+ (void)updateHttpDomain:(NSString *)httpDomain;

//animations
+ (void)shakeView:(UIView *)view;
+ (void)shakeTableViewCell:(UITableViewCell *)cell;
@end
