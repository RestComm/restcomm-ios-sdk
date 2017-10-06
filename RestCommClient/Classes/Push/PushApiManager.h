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

/**
 *  Communicate with the Restcomm services
 */
@interface PushApiManager : NSObject

/*
 *  Initialize a new PushApiManager with parameters
 *
 *  @param parameters Possible keys: <br>
 *  <b>username"</b>: username <br>
 *  <b>password</b>: password for an account<br>
 */
- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password;

/*
 *  Fetch an account sid from server for given email
 *
 * @param email
 *
 * @param completionHandler will be filled with the account sid if success, otherwise with NSError
 */
- (void)getAccountSidWithRequestForEmail:(NSString *)email andCompletionHandler:(void (^)( NSString *accountSid, NSError *error))completionHandler;

/*
 *  Fetch the client sid from server for given account sid and username
 *
 * @param accountSid
 * @param signalingUsername identity (or address of record) for the client
 *
 * @param completionHandler will be filled with the client sid if success, otherwise with NSError
 */
- (void)getClientSidWithAccountSid:(NSString *)accountSid signalingUsername:(NSString *)signalingUsername andCompletionHandler:(void (^)( NSString *clientSid, NSError *error))completionHandler;

/*
 *  Fetch the application sid from server for given friendly name
 *
 * @param friendlyName Name of the application for which we want sid
 *
 * @param completionHandler will be filled with the application sid if success, otherwise with NSError
 */
- (void)getApplicationSidForFriendlyName:(NSString *)friendlyName withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler;

/*
 *  Create the application with given friendly name
 *
 * @param friendlyName Name of the application we want to register
 * @param isSendbox should be true if we want to create an application with sendbox push capability
 *
 * @param completionHandler will be filled with the application sid if success, otherwise with NSError
 */
- (void)createApplicationWithFriendlyName:(NSString *)friendlyName isSendbox:(BOOL)isSendbox withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler;

/*
 *  Fetch the credentials sid
 *
 * @param completionHandler will be filled with the credentials sid if success, otherwise with NSError
 */
- (void)getCredentialsSidWithCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler;

/*
 *  Create the Credentials for given certificates, application sid and friendly name
 *
 * @param certificate base64 encoded string of public certificate
 * @param privateKey base64 encoded string of private RSA certificate
 * @param applicationSid application sid for which we want to create certificate
 * @param friendlyName friendly name of the application registered on server
 *
 * @param completionHandler will be filled with the credentials sid if success, otherwise with NSError
 */
- (void)createCredentialsWithCertificate:(NSString *)certificate privateKey:(NSString *)privateKey applicationSid:(NSString *)applicationSid friendlyName:(NSString *)friendlyName andCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler;

/*
 *  Fatch the bindingSid and token
 *
 *  @param completionHandler will be filled with the binding sid, and token for it, if success, otherwise with NSError
 */
- (void)checkExistingBindingSidWithCompletionHandler:(void (^)(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error))completionHandler;

/*
 *  Create the Binding
 *  @param binding
 *  @param completionHandler will be filled with the binding sid if success, otherwise with NSError
 */
- (void)createBinding:(Binding *)binding andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler;

/*
 *  Update the Binding for binding sid
 *  @param binding
 *  @param bindingSid binding sid
 *  @param completionHandler will be filled with the binding sid if success, otherwise with NSError
 */
- (void)updateBinding:(Binding *)binding forBindingSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler;

@end

