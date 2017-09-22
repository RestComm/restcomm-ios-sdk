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
#import "PushCommunicationManager.h"

//keys
NSString *const kAccountSidKey = @"accountSidKey";
NSString *const kClientSidKey = @"clientSidKey";
NSString *const kApplicationSidKey = @"applicationSidKey";
NSString *const kBindingSidKey = @"bindingSidKey";
NSString *const kCredentialSidKey = @"credentialSidKey";

@implementation PushHandler{
    PushCommunicationManager *pushCommManager;
    NSString *signalingUsername;
    NSString *username;
    NSString *password;
    NSString *friendlyName;
    NSString *rescommAccountEmail;
    NSString *token;
    BOOL sandbox;
    
    //certificate data
    NSString *certificate;
    NSString *privateKey;
}

- (id)initWithParameters:(NSDictionary *)parameters{
    self = [super init];
    if (self){
        username = [parameters objectForKey:@"username"];
        password = [parameters objectForKey:@"password"];
        signalingUsername = [parameters objectForKey:@"signaling-username"];
        friendlyName = [parameters objectForKey:@"friendly-name"];
        certificate = [parameters objectForKey:@"certificate"];
        privateKey = [parameters objectForKey:@"private-key"];
        rescommAccountEmail = [parameters objectForKey:@"rescomm-account-email"];
        token = [parameters objectForKey:@"token"];
        sandbox = [parameters objectForKey:@"is-sandbox"];
        
        pushCommManager = [[PushCommunicationManager alloc] initWithUsername:username andPassword:password];
    }
    return self;
}

- (void)registerDevice{
    if (!token || token.length == 0){
        RCLogError("Push notification token is nil or empty.");
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //before calling the pinding api, we need to get:
        //account sid
        //client sid
        //application sid
        
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
                                [self getCredenitalsSid:applicationSid andWithCompletionHandler:^(NSString *credentialsSid) {
                                    //if binding sid is available, we should update
                                    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
                                    NSString *bindingSid = [appDefaults objectForKey:kBindingSidKey];
                                
                                    //create the binding object
                                    Binding *binding;
                                    binding = [[Binding alloc] initWithIdentity:clientSid
                                                                 applicationSid:applicationSid
                                                                     andAddress:token];
                                    
                                    if (bindingSid && bindingSid.length > 0){
                                        [pushCommManager updateBinding:binding forBindingSid:bindingSid andCompletionHandler:^(NSError *error) {
                                            if (error){
                                                RCLogError([error.localizedDescription UTF8String]);
                                            }
                                        }];
                                    } else {
                                        [pushCommManager createBinding:binding andCompletionHandler:^(NSError *error) {
                                            if (error){
                                                RCLogError([error.localizedDescription UTF8String]);
                                            }
                                        }];
                                    }
                                }];
                            }
                        }];
                    }
                }];
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
    RCLogError("Rescomm Account email is nil or empty.");
    
    //Account sid is not found, we need to ask server for it
    [pushCommManager getAccountSidWithRequestForEmail:rescommAccountEmail andCompletionHandler:^(NSString *accountSid, NSError *error) {
    
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
    [pushCommManager getClientSidWithAccountSid:accountSid signalingUsername:signalingUsername andCompletionHandler:^(NSString *clientSid, NSError *error) {
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
    [pushCommManager getApplicationSidwithCompletionHandler:^(NSString *applicationSid, NSError *error) {
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
                [pushCommManager createApplicationWithFriendlyName:friendlyName withCompletionHandler:^(NSString *applicationSid, NSError *error) {
                    [appDefaults setObject:applicationSid forKey:kApplicationSidKey];
                    completionHandler(applicationSid);
                }];
            }
        }
    }];
}

- (void)getCredenitalsSid:(NSString *)applicationSid andWithCompletionHandler:(void (^)(NSString *credentialsSid))completionHandler{
    //check is client id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *credentialSid = [appDefaults objectForKey:kCredentialSidKey];
    if (credentialSid && credentialSid.length > 0){
        completionHandler(credentialSid);
        return;
    }
    
    //Credentials sid is not found, we need to ask server for it
    [pushCommManager createCredentialsWithCertificate:certificate privateKey:privateKey applicationSid:applicationSid friendlyName:friendlyName isSendBox:sandbox andCompletionHandler:^(NSString *credentialsSid, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            [appDefaults setObject:credentialSid forKey:kCredentialSidKey];
            completionHandler(credentialSid);
        }
        
    }];
}

@end
