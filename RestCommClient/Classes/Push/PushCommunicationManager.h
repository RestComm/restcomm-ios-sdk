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
#import "Binding.h"

@interface PushCommunicationManager : NSObject

- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password;

- (void)getAccountSidWithRequestForEmail:(NSString *)email andCompletionHandler:(void (^)( NSString *accountSid, NSError *error))completionHandler;

- (void)getClientSidWithAccountSid:(NSString *)accountSid signalingUsername:(NSString *)signalingUsername andCompletionHandler:(void (^)( NSString *clientSid, NSError *error))completionHandler;

- (void)getApplicationSidForFriendlyName:(NSString *)friendlyName withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler;

- (void)createApplicationWithFriendlyName:(NSString *)friendlyName isSendbox:(BOOL)isSendbox withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler;

- (void)getCredentialsSidWithCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler;

- (void)createCredentialsWithCertificate:(NSString *)certificate privateKey:(NSString *)privateKey applicationSid:(NSString *)applicationSid friendlyName:(NSString *)friendlyName andCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler;

- (void)checkExistingBindingSidWithCompletionHandler:(void (^)(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error))completionHandler;

- (void)createBinding:(Binding *)binding andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler;

- (void)updateBinding:(Binding *)binding forBindingSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler;

@end
