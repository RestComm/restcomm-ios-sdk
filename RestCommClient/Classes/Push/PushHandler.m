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
 */


#import "PushHandler.h"
#import "common.h"
#import "PushApiManager.h"
#import "RestCommClient.h"

//keys
NSString *const kAccountSidKey = @"accountSidKey";
NSString *const kClientSidKey = @"clientSidKey";
NSString *const kApplicationSidKey = @"applicationSidKey";
NSString *const kCredentialSidKey = @"credentialSidKey";

@interface PushHandler()
@property (nonatomic, weak) id<RCRegisterPushDelegate> delegate;
@end

@implementation PushHandler{
    PushApiManager *pushApiManager;
    NSString *signalingUsername;
    NSString *username;
    NSString *password;
    NSString *friendlyName;
    NSString *rescommAccountEmail;
    NSString *token;
    BOOL sandbox;
    
    //certificate data directory
    NSString *certificatePublicPath;
    NSString *certificatePrivatePath;
}

- (id)initWithParameters:(NSDictionary *)parameters andDelegate:(id<RCRegisterPushDelegate>)delegate{
    self = [super init];
    if (self){
        username = [parameters objectForKey:@"username"];
        password = [parameters objectForKey:@"password"];
        signalingUsername = [parameters objectForKey:@"signaling-username"];
        friendlyName = [parameters objectForKey:@"friendly-name"];
        certificatePublicPath = [parameters objectForKey:@"push-certificate-public-path"];
        certificatePrivatePath = [parameters objectForKey:@"push-certificate-private-path"];
        rescommAccountEmail = [parameters objectForKey:@"rescomm-account-email"];
        token = [parameters objectForKey:@"token"];
        sandbox = [[parameters objectForKey:@"is-sandbox"] boolValue];
        
        pushApiManager = [[PushApiManager alloc] initWithUsername:username andPassword:password];
        self.delegate = delegate;
    }
    return self;
}

- (void)registerDevice{
    if (!token || token.length == 0){
        RCLogError("Push notification token is nil or empty.");
        return;
    }
    __weak PushHandler *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //before calling the pinding api, we need to get:
        //account sid
        //client sid
        //application sid
        //credentials sid
        //binding sid
        
        //account id
        [self getAccountSidWithCompletionHandler:^(NSString *accountSid){
            if (accountSid){
                //get client sid
                [self getClientSidForAccountSid:accountSid andWithCompletionHandler:^(NSString *clientSid) {
                    if (clientSid){
                        //get application sid
                        [self getApplicationSidWithCompletionHandler:^(NSString *applicationSid) {
                            if (applicationSid){
                                //get credentials sid
                                [self getCredentialsSid:applicationSid andWithCompletionHandler:^(NSString *credentialsSid) {
                                    if (credentialsSid){
                                        //check existing binding sid
                                        [self checkBindingSidWithCompletionHandler:^(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error) {
                                            if (error){
                                                RCLogError("Error checking binding sid: %@", error);
                                                if(self.delegate && [self.delegate respondsToSelector:@selector(rcRegisteredForPush:)]){
                                                     [weakSelf.delegate rcRegisteredForPush:error];
                                                }
                                            } else {
                                                //create the binding object
                                                Binding *binding = [[Binding alloc] initWithClientSid:clientSid
                                                                                      applicationSid:applicationSid
                                                                                          andAddress:token];
                                                
                                                //its and existing sid, we should update sid if savedTokenOnServer is different than token
                                                if (bindingSid && bindingSid.length > 0){
                                                    if (![savedTokenOnServer isEqualToString:token]){
                                                        [pushApiManager updateBinding:binding forBindingSid:bindingSid andCompletionHandler:^(NSString *bindingSid, NSError *error) {
                                                             if(self.delegate && [self.delegate respondsToSelector:@selector(rcRegisteredForPush:)]){
                                                                  [weakSelf.delegate rcRegisteredForPush:error];
                                                             }
                                                        }];
                                                    } else {
                                                        RCLogInfo("Binding sid is same on server.");
                                                        if(self.delegate && [self.delegate respondsToSelector:@selector(rcRegisteredForPush:)]){
                                                            [weakSelf.delegate rcRegisteredForPush:nil];
                                                        }
                                                    }
                                                } else {
                                                    [pushApiManager createBinding:binding andCompletionHandler:^(NSString *bindingSid, NSError *error) {
                                                        if(self.delegate && [self.delegate respondsToSelector:@selector(rcRegisteredForPush:)]){
                                                            [weakSelf.delegate rcRegisteredForPush:error];
                                                        }
                                                    }];
                                                }
                                            }
                                            
                                        }];
                                    } else {
                                        [weakSelf formatAndDelegateError: @"CredentialsSid is nil or empty."];
                                    }
                                }];
                            } else {
                                [weakSelf formatAndDelegateError: @"ApplicationSid is nil or empty."];
                            }
                        }];
                    } else {
                        [weakSelf formatAndDelegateError: @"ClientSid is nil or empty."];
                    }
                }];
            } else {
                  [weakSelf formatAndDelegateError: @"Account sid is nil or empty."];
            }
        }];
        
    });
    
}

- (void)getAccountSidWithCompletionHandler:(void (^)(NSString *accountSid))completionHandler{
    //check is account id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *accountSid = [appDefaults objectForKey:kAccountSidKey];
    if (accountSid && accountSid.length > 0){
        completionHandler(accountSid);
        return;
    }
    
    //Account sid is not found, we need to ask server for it
    [pushApiManager getAccountSidWithRequestForEmail:rescommAccountEmail andCompletionHandler:^(NSString *accountSid, NSError *error) {
        
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            [appDefaults setObject:accountSid forKey:kAccountSidKey];
            completionHandler(accountSid);
        }
    }];
}

- (void)getClientSidForAccountSid:(NSString *)accountSid andWithCompletionHandler:(void (^)(NSString *clientSid))completionHandler{
    //check is client id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *clientSid = [appDefaults objectForKey:kClientSidKey];
    if (clientSid && clientSid.length > 0){
        completionHandler(clientSid);
        return;
    }
    
    //Client sid is not found, we need to ask server for it
    [pushApiManager getClientSidWithAccountSid:accountSid signalingUsername:signalingUsername andCompletionHandler:^(NSString *clientSid, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            [appDefaults setObject:clientSid forKey:kClientSidKey];
            completionHandler(clientSid);
        }
    }];
}

- (void)getApplicationSidWithCompletionHandler:(void (^)(NSString *applicationSid))completionHandler{
    //check is application id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *applicationSid = [appDefaults objectForKey:kApplicationSidKey];
    
    if (applicationSid && applicationSid.length > 0){
        completionHandler(applicationSid);
        return;
    }
    //Application sid is not found, we need to ask server for it
    [pushApiManager getApplicationSidForFriendlyName:friendlyName withCompletionHandler:^(NSString *applicationSid, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            if (applicationSid){
                [appDefaults setObject:applicationSid forKey:kApplicationSidKey];
                completionHandler(applicationSid);
            } else {
                //there is no application on the server
                //we should add it : firendlyName
                [pushApiManager createApplicationWithFriendlyName:friendlyName isSendbox:sandbox withCompletionHandler:^(NSString *applicationSid, NSError *error) {
                    [appDefaults setObject:applicationSid forKey:kApplicationSidKey];
                    completionHandler(applicationSid);
                }];
            }
        }
    }];
}

- (void)getCredentialsSid:(NSString *)applicationSid andWithCompletionHandler:(void (^)(NSString *credentialsSid))completionHandler{
    //check is client id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *credentialSid = [appDefaults objectForKey:kCredentialSidKey];
    if (credentialSid && credentialSid.length > 0){
        completionHandler(credentialSid);
        return;
    }
    
    //Credentials sid is not found, we need to ask server for it
    [pushApiManager getCredentialsSidWithCompletionHandler:^(NSString *credentialsSid, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            if (credentialsSid){
                [appDefaults setObject:credentialsSid forKey:kCredentialSidKey];
                completionHandler(credentialsSid);
            } else {
                //there are no credentials on the server
                //we should add them
                //get certificates files and read them
                NSString *certificate =  [NSString stringWithContentsOfFile:certificatePublicPath encoding:NSUTF8StringEncoding error:NULL];
                NSString *privateKey =  [NSString stringWithContentsOfFile:certificatePrivatePath encoding:NSUTF8StringEncoding error:NULL];
                
                
                
                // Get NSString from NSData object in Base64
                NSString *base64Certificate = [[certificate dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                NSString *base64PrivateKey = [[privateKey dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                
                
                [pushApiManager createCredentialsWithCertificate:base64Certificate privateKey:base64PrivateKey applicationSid:applicationSid friendlyName:friendlyName andCompletionHandler:^(NSString *credentialsSid, NSError *error) {
                    if (error){
                        RCLogError([error.localizedDescription UTF8String]);
                        completionHandler(nil);
                    } else {
                        [appDefaults setObject:credentialsSid forKey:kCredentialSidKey];
                        completionHandler(credentialsSid);
                    }
                    
                }];
            }
        }
    }];
}

- (void)checkBindingSidWithCompletionHandler:(void (^)(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error))completionHandler{
    [pushApiManager checkExistingBindingSidWithCompletionHandler:^(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error) {
        if (error){
            completionHandler(nil, nil, error);
            return;
        }
        completionHandler(bindingSid, savedTokenOnServer, nil);
        return;
    }];
    
}

#pragma mark - Helpers
- (void)formatAndDelegateError:(NSString *)errorDescription{
    NSError *errorForDelegate =[[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                 code:ERROR_PUSH_REGISTER
                                             userInfo:@{ NSLocalizedDescriptionKey: errorDescription}];
    if(self.delegate && [self.delegate respondsToSelector:@selector(rcRegisteredForPush:)]){
        [self.delegate rcRegisteredForPush:errorForDelegate];
    }
    RCLogError([errorDescription UTF8String]);
}

@end

