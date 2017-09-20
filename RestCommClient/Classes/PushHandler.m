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
#import "BindingCommunicationManager.h"

//keys
NSString *const kAccountSidKey = @"accountSidKey";
NSString *const kClientSidKey = @"clientSidKey";
NSString *const kApplicationSidKey = @"applicationSidKey";
NSString *const kBindingSidKey = @"bindingSidKey";

@implementation PushHandler{
    BindingCommunicationManager *bindingCommManager;
}

- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password{
    self = [super init];
    if (self){
        bindingCommManager = [[BindingCommunicationManager alloc] initWithUsername:username andPassword:password];
    }
    return self;
}

- (void)registerDeviceWithToken:(NSString *)pushNotificationToken{
    if (!pushNotificationToken || pushNotificationToken.length == 0){
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
                            //if binding sid is available, we should update
                            NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
                            NSString *bindingSid = [appDefaults objectForKey:kBindingSidKey];
                            
                            //create the binding object
                            Binding *binding = [[Binding alloc] initWithIdentity:clientSid
                                                                  applicationSid:applicationSid
                                                                      andAddress:pushNotificationToken];
                            if (bindingSid && bindingSid.length > 0){
                                [bindingCommManager updateBinding:binding forBindingSid:bindingSid andCompletionHandler:^(NSError *error) {
                                    if (error){
                                        RCLogError([error.localizedDescription UTF8String]);
                                    }
                                }];
                            } else {
                                [bindingCommManager createBinding:binding andCompletionHandler:^(NSError *error) {
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
        
    });
}

- (void)getAccountSidWithCompletionHandler:(void (^)(NSString *accountSid))completionHandler{
    //check is account id is already saved in user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *accountSid = [appDefaults objectForKey:kAccountSidKey];
    if (accountSid && accountSid.length > 0){
        completionHandler(accountSid);
    }
    
    //Account sid is not found, we need to ask server for it
    [bindingCommManager getAccountSidWithRequestWidthCompletionHandler:^(NSString *accountSid, NSError *error) {
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
    }
    
    //Client sid is not found, we need to ask server for it
    [bindingCommManager getClientSidWithAccountSid:accountSid andCompletionHandler:^(NSString *clientSid, NSError *error) {
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
    }
    
    //Application sid is not found, we need to ask server for it
    [bindingCommManager getApplicationSidwithCompletionHandler:^(NSString *applicationSid, NSError *error) {
        if (error){
            RCLogError([error.localizedDescription UTF8String]);
            completionHandler(nil);
        } else {
            [appDefaults setObject:applicationSid forKey:kApplicationSidKey];
            completionHandler(applicationSid);
        }
    }];
}






@end
