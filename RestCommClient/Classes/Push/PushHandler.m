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
NSString *const kApplicationKey = @"applicationKey";
NSString *const kCredentialsKey = @"credentialsKey";

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
        password = [parameters objectForKey:@"password"];
        signalingUsername = [parameters objectForKey:@"signaling-username"];
        friendlyName = [parameters objectForKey:@"friendly-name"];
        certificatePublicPath = [parameters objectForKey:@"push-certificate-public-path"];
        certificatePrivatePath = [parameters objectForKey:@"push-certificate-private-path"];
        rescommAccountEmail = [parameters objectForKey:@"rescomm-account-email"];
        token = [parameters objectForKey:@"token"];
        sandbox = [[parameters objectForKey:@"is-sandbox"] boolValue];
        NSString *pushDomain = [parameters objectForKey:@"push-domain"];
        NSString *signalingDomain = [parameters objectForKey:@"signaling-domain"];
        
        pushApiManager = [[PushApiManager alloc] initWithUsername:rescommAccountEmail password:password pushDomain:pushDomain andDomain:signalingDomain];
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - Register Device

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
                                        [self checkBindingSidWithCompletionHandler:^(RCBinding *binding, NSError *error) {
                                            if (error){
                                                RCLogError([[NSString stringWithFormat:@"Error checking binding sid: %@", error] UTF8String]);
                                                if(self.delegate && [self.delegate respondsToSelector:@selector(registeredForPush:)]){
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        [weakSelf.delegate registeredForPush:error];
                                                    });
                                                }
                                            } else {
                                                //its and existing sid, we should update sid if savedTokenOnServer is different than token
                                                if (binding){
                                                    if (![binding.address isEqualToString:token]){
                                                        binding.address = token;
                                                        [pushApiManager updateBinding:binding andCompletionHandler:^(RCBinding *binding, NSError *error) {
                                                             if(self.delegate && [self.delegate respondsToSelector:@selector(registeredForPush:)]){
                                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                                      [weakSelf.delegate registeredForPush:error];
                                                                  });
                                                             }
                                                        }];
                                                    } else {
                                                        RCLogInfo("Binding sid is same on server. No need to update");
                                                        if(self.delegate && [self.delegate respondsToSelector:@selector(registeredForPush:)]){
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 [weakSelf.delegate registeredForPush:nil];
                                                             });
                                                        }
                                                    }
                                                } else {
                                                    RCBinding *bindingToSend = [[RCBinding alloc] initWithSid:@"" identity:clientSid applicationSid:applicationSid andAddress:token];
                                                    [pushApiManager createBinding:bindingToSend andCompletionHandler:^(RCBinding *binding, NSError *error) {
                                                        if(self.delegate && [self.delegate respondsToSelector:@selector(registeredForPush:)]){
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 [weakSelf.delegate registeredForPush:error];
                                                             });
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

#pragma mark - Account Sid

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

#pragma mark - Client Sid

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

#pragma mark - Application Sid

- (void)getApplicationSidWithCompletionHandler:(void (^)(NSString *applicationSid))completionHandler{
    //check is application id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *applicationData = [appDefaults objectForKey:kApplicationKey];
    RCApplication *application = [NSKeyedUnarchiver unarchiveObjectWithData:applicationData];
    
    //** IMPORTANT **//
    //we use the application for every reguest and entity creation
    if (application && application.sandbox == sandbox){
        completionHandler(application.sid);
        return;
    }
    //Application sid is not found, we need to ask server for it
    [pushApiManager getApplicationForFriendlyName:friendlyName isSandbox:sandbox withCompletionHandler:^(RCApplication *application, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            if (application && application.sandbox == sandbox){
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:application];
                [appDefaults setObject:data forKey:kApplicationKey];
                completionHandler(application.sid);
            } else {
                //there is no application on the server
                //we should add it : firendlyName
                RCApplication *appToSend = [[RCApplication alloc] initWithSid:@"" friendlyName:friendlyName andSandbox:sandbox];
                [pushApiManager createApplication:appToSend withCompletionHandler:^(RCApplication *application, NSError *error) {
                    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:application];
                    [appDefaults setObject:data forKey:kApplicationKey];

                    completionHandler(application.sid);
                }];
            }
        }
    }];
}

#pragma mark - Credentials Sid

- (void)getCredentialsSid:(NSString *)applicationSid andWithCompletionHandler:(void (^)(NSString *credentialsSid))completionHandler{
    //check is client id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *credentialsData = [appDefaults objectForKey:kCredentialsKey];
    RCCredentials *credentials = [NSKeyedUnarchiver unarchiveObjectWithData:credentialsData];
    
    if (credentials){
        if ([applicationSid isEqualToString:credentials.applicationSid]){
            completionHandler(credentials.sid);
            return;
        }
    }
    
    NSData *applicationData = [appDefaults objectForKey:kApplicationKey];
    RCApplication *application = [NSKeyedUnarchiver unarchiveObjectWithData:applicationData];
    
    //Credentials sid is not found, we need to ask server for it
    [pushApiManager getCredentialsForApplication:(RCApplication *)application withCompletionHandler:^(RCCredentials *credentials, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            if (credentials){
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:credentials];
                [appDefaults setObject:data forKey:kCredentialsKey];
                completionHandler(credentials.sid);
            } else {
                //there are no credentials on the server
                //we should add them
                //get certificates files and read them
                NSString *certificate =  [NSString stringWithContentsOfFile:certificatePublicPath encoding:NSUTF8StringEncoding error:NULL];
                NSString *privateKey =  [NSString stringWithContentsOfFile:certificatePrivatePath encoding:NSUTF8StringEncoding error:NULL];
                
                // Get NSString from NSData object in Base64
                NSString *base64Certificate = [[certificate dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                NSString *base64PrivateKey = [[privateKey dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
                
                RCCredentials *credetntilasToSend = [[RCCredentials alloc] initWithSid:@"" applicationSid:applicationSid credentialType:@"apn" certificate:base64Certificate andPrivateKey:base64PrivateKey];
                
                [pushApiManager createCredentials:credetntilasToSend withCompletionHandler:^(RCCredentials *credentials, NSError *error) {
                    if (error){
                        RCLogError([error.localizedDescription UTF8String]);
                        completionHandler(nil);
                    } else {
                        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:credentials];
                        [appDefaults setObject:data forKey:kCredentialsKey];
                        completionHandler(credentials.sid);
                    }
                    
                }];
            }
        }
    }];
}

#pragma mark - Binding Sid

- (void)checkBindingSidWithCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *applicationData = [appDefaults objectForKey:kApplicationKey];
    RCApplication *application = [NSKeyedUnarchiver unarchiveObjectWithData:applicationData];
    
    [pushApiManager checkExistingBindingSidForApplication:application WithCompletionHandler:^(RCBinding *binding, NSError *error) {
        if (error){
            completionHandler(nil, error);
            return;
        }
        if (binding){
            completionHandler(binding, nil);
            return;
        }
        completionHandler(nil, nil);
        return;
    }];
    
}

#pragma mark - Helpers

- (void)formatAndDelegateError:(NSString *)errorDescription{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *errorForDelegate =[[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                     code:ERROR_PUSH_REGISTER
                                                 userInfo:@{ NSLocalizedDescriptionKey: errorDescription}];
        if(self.delegate && [self.delegate respondsToSelector:@selector(registeredForPush:)]){
            [self.delegate registeredForPush:errorForDelegate];
        }
        RCLogError([errorDescription UTF8String]);
    });
}

@end

