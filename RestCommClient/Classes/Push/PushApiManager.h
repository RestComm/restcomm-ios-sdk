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
#import "RCBinding.h"
#import "RCApplication.h"
#import "RCCredentials.h"

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
 *  <b>pushDomain</b>: push notification domain<br>
 *  <b>domain</b>: domain<br>
 */
- (id)initWithUsername:(NSString *)username password:(NSString *)password pushDomain:(NSString *)pushDomain andDomain:(NSString *)domain;

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
 *  Fetch the application object from server for given friendly name
 *
 * @param friendlyName Name of the application for which we want sid
 * @param isSandbox should be true if we want to create an application with sandbox push capability
 *
 * @param completionHandler will be filled with the application if success, otherwise with NSError
 */
- (void)getApplicationForFriendlyName:(NSString *)friendlyName isSandbox:(BOOL)sandbox withCompletionHandler:(void (^)( RCApplication *application, NSError *error))completionHandler;

/*
 *  Create the application on server for given application object
 *
 * @param application RCApplication object
 *
 * @param completionHandler will be filled with the application if success, otherwise with NSError
 */
- (void)createApplication:(RCApplication *)application withCompletionHandler:(void (^)( RCApplication *application, NSError *error))completionHandler;

/*
 *  Fetch the credentials for the given application
 *
 * @param application RCApplication object
 *
 * @param completionHandler will be filled with the credentials if success, otherwise with NSError
 */
- (void)getCredentialsForApplication:(RCApplication *)application withCompletionHandler:(void (^)( RCCredentials *credentials, NSError *error))completionHandler;

/*
 *  Create the Credentials for given certificates, application sid and friendly name
 *
 * @param credentials RCCredentials object
 *
 * @param completionHandler will be filled with the credentials  if success, otherwise with NSError
 */
- (void)createCredentials:(RCCredentials *)credentials withCompletionHandler:(void (^)(RCCredentials *credentialsSid, NSError *error))completionHandler;

/*
 *  Fatch the bindingSid and token
 *
 *  @param application RCApplication object
 *
 *  @param completionHandler will be filled with the binding sid, and token for it, if success, otherwise with NSError
 */
- (void)checkExistingBindingSidForApplication:(RCApplication *)application WithCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler;

/*
 *  Create the RCBinding
 *  @param binding
 *  @param completionHandler will be filled with the binding if success, otherwise with NSError
 */
- (void)createBinding:(RCBinding *)binding andCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler;

/*
 *  Update the RCBinding for binding sid
 *  @param binding
 *  @param completionHandler will be filled with the binding if success, otherwise with NSError
 */
- (void)updateBinding:(RCBinding *)binding andCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler;

@end

