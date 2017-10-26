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

#import "PushApiManager.h"
#import "RestCommClient.h"
#import "common.h"

NSString *const kSignalingDomain = @"cloud.restcomm.com";
NSString *const kAccountSidUrl = @"/restcomm/2012-04-24/Accounts.json";
NSString *const kClientSidUrl = @"/restcomm/2012-04-24/Accounts";
NSString *const kPushPath = @"pushNotifications";


@implementation PushApiManager{
    NSString *pUsername;
    NSString *pPassword;
    NSURLSession *session;
    NSString *pushDomain;
}


- (id)initWithUsername:(NSString *)username password:(NSString *)password andPushDomain:(NSString *)domain{
    self = [super init];
    if (self){
        pUsername = username;
        pPassword = password;
        session = [NSURLSession sharedSession];
        pushDomain = domain;
    }
    return self;
}

- (NSMutableURLRequest *)createUrlRequestWithUrl:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSString *basic = [NSString stringWithFormat:@"%@:%@", pUsername, pPassword];
    NSData *encodeData = [basic dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [encodeData base64EncodedStringWithOptions:0]];
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    return request;
}


- (void)getAccountSidWithRequestForEmail:(NSString *)email andCompletionHandler:(void (^)( NSString *accountSid, NSError *error))completionHandler{
    NSString *encodedEmail = [email stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@/%@", kSignalingDomain, kAccountSidUrl, encodedEmail]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getAccountSidWithRequestForEmail for email: %@", email] UTF8String]);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getAccountSidWithRequestForEmail ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getAccountSidWithRequestForEmail ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing account sid"]);
            return;
        }
        
        if (dict){
            NSString *accountSid = [dict objectForKey:@"sid"];
            RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getAccountSidWithRequestForEmail SUCCESS, account sid: %@", accountSid] UTF8String]);
            completionHandler(accountSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
        
    }] resume];
}

- (void)getClientSidWithAccountSid:(NSString *)accountSid signalingUsername:(NSString *)signalingUsername andCompletionHandler:(void (^)( NSString *clientSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@/%@/Clients.json", kSignalingDomain, kClientSidUrl, accountSid]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getClientSidWithAccountSid for accountSid: %@; signalingUsername: %@", accountSid, signalingUsername] UTF8String]);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getClientSidWithAccountSid ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getClientSidWithAccountSid ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing client sid"]);
            return;
        }
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i<arr.count; i ++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"login"] isEqualToString:signalingUsername]){
                NSString *clientSid = [dict objectForKey:@"sid"];
                RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getClientSidWithAccountSid SUCCESS, client sid: %@", clientSid] UTF8String]);
                completionHandler(clientSid, nil);
                return;
                
            }
        }
        completionHandler(nil, nil);
    }] resume];
}


- (void)getApplicationForFriendlyName:(NSString *)friendlyName isSandbox:(BOOL)sandbox withCompletionHandler:(void (^)(RCApplication *application, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/applications", pushDomain, kPushPath]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getApplicationForFriendlyName for friendlyName: %@; isSandbox: %@", friendlyName, sandbox?@"YES":@"NO"] UTF8String]);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getApplicationForFriendlyName ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getApplicationForFriendlyName ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing application sid"]);
            return;
        }
        
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i<arr.count; i ++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"FriendlyName"] isEqualToString:friendlyName] && [[dict objectForKey:@"Sandbox"]
                                                                                       boolValue] == sandbox){
                RCApplication *rcApplication = [[RCApplication alloc] initWithDictionary:dict];
                RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getApplicationForFriendlyName SUCCESS-> %@", rcApplication] UTF8String]);
                completionHandler(rcApplication, nil);
                return;
            }
        }
        completionHandler(nil, nil);
        
        
    }] resume];
}

- (void)createApplication:(RCApplication *)application withCompletionHandler:(void (^)( RCApplication *application, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/applications", pushDomain, kPushPath]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createApplication with %@", application] UTF8String]);
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [nameDictionary setObject:application.friendlyName forKey:@"FriendlyName"];
    if (application.sandbox){
        [nameDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"Sandbox"];
    }
    
    NSError *jsonSerializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nameDictionary options:NSJSONWritingPrettyPrinted error:&jsonSerializationError];
    
    if (jsonSerializationError){
        RCLogError([[NSString stringWithFormat:@"PushApiManager: createApplication ERROR: %@", jsonSerializationError.description] UTF8String]);
        completionHandler(nil, [self getErrorWithDescription:@"Error creating JSON for application request"]);
        return;
    }
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createApplication ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createApplication ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing application sid"]);
            return;
        }
        
        if (dict){
            RCApplication *rcApplication = [[RCApplication alloc] initWithDictionary:dict];
            RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createApplication SUCCESS-> %@", rcApplication] UTF8String]);
            completionHandler(rcApplication, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}

- (void)getCredentialsForApplication:(RCApplication *)application withCompletionHandler:(void (^)( RCCredentials *credentials, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/credentials", pushDomain, kPushPath]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];

    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getCredentialsForApplication for %@", application] UTF8String]);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getCredentialsForApplication ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: getCredentialsForApplication ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing credentials sid"]);
            return;
        }
        
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i< arr.count; i++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"ApplicationSid"] isEqualToString:application.sid]){
                RCCredentials *rcCredentials = [[RCCredentials alloc] initWithDictionary:dict];
                RCLogInfo([[NSString stringWithFormat:@"PushApiManager: getCredentialsForApplication SUCCESS -> %@", rcCredentials] UTF8String]);
                completionHandler(rcCredentials, nil);
                return;
            }
        }
        completionHandler(nil, nil);
        
        
    }] resume];
}

- (void)createCredentials:(RCCredentials *)credentials withCompletionHandler:(void (^)(RCCredentials *credentials, NSError *error))completionHandler{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/credentials", pushDomain, kPushPath]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createCredentials with %@", credentials] UTF8String]);
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [nameDictionary setObject:credentials.applicationSid forKey:@"ApplicationSid"];
    [nameDictionary setObject:credentials.credentialType forKey:@"CredentialType"];
    [nameDictionary setObject:credentials.certificate forKey:@"Certificate"];
    [nameDictionary setObject:credentials.privateKey forKey:@"PrivateKey"];
    
    NSError *jsonSerializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nameDictionary options:NSJSONWritingPrettyPrinted error:&jsonSerializationError];
    
    if (jsonSerializationError){
        RCLogError([[NSString stringWithFormat:@"PushApiManager: createCredentials ERROR: %@", jsonSerializationError.description] UTF8String]);
        completionHandler(nil, [self getErrorWithDescription:@"Error creating JSON for application request"]);
        return;
    }
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createCredentials ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createCredentials ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing credentials sid"]);
            return;
        }
        
        if (dict){
            RCCredentials *rcCredentials = [[RCCredentials alloc] initWithDictionary:dict];
            RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createCredentials SUCCESS -> %@", rcCredentials] UTF8String]);
            completionHandler(rcCredentials, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}


- (void)checkExistingBindingSidForApplication:(RCApplication *)application WithCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/bindings", pushDomain, kPushPath]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: checkExistingBindingSidForApplication for %@", application] UTF8String]);
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: checkExistingBindingSidForApplication ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: checkExistingBindingSidForApplication ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing binding sid"]);
            return;
        }
        
        if (jsonArray){
            //chek to see if user have already sid for Binding type apn
            NSArray *arr = (NSArray *)jsonArray;
            for (int i=0; i< arr.count; i++){
                NSDictionary *dict = arr[i];
                if ([[dict objectForKey:@"ApplicationSid"] isEqualToString:application.sid]){
                    RCBinding *rcBinding = [[RCBinding alloc]initWithDictionary:dict];
                    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: checkExistingBindingSidForApplication SUCCESS -> %@", rcBinding] UTF8String]);
                    completionHandler(rcBinding, nil);
                    return;
                }
            }
            completionHandler(nil, nil);
        } else {
            completionHandler(nil, nil);
        }
    }] resume];
}

- (void)createBinding:(RCBinding *)binding andCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler{
    [self createOrUpdateBinding:binding forSid:nil andCompletionHandler:completionHandler];
}

- (void)updateBinding:(RCBinding *)binding andCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler{
    [self createOrUpdateBinding:binding forSid:binding.sid andCompletionHandler:completionHandler];
}

- (void)createOrUpdateBinding:(RCBinding *)binding forSid:(NSString *)bindingSid andCompletionHandler:(void (^)(RCBinding *binding, NSError *error))completionHandler{
    RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createOrUpdateBinding with %@", binding] UTF8String]);
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/bindings", pushDomain, kPushPath]];
    if (bindingSid){
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@/bindings/%@", pushDomain, kPushPath, bindingSid]];
    }
    
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    if (bindingSid){
        [request setHTTPMethod:@"PUT"];
    } else {
        [request setHTTPMethod:@"POST"];
    }
    
    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [propertyDictionary setObject:binding.identity forKey:@"Identity"];
    [propertyDictionary setObject:binding.applicationSid forKey:@"ApplicationSid"];
    [propertyDictionary setObject:binding.bindingType forKey:@"BindingType"];
    [propertyDictionary setObject:binding.address forKey:@"Address"];
    
    
    NSError *error;
    NSData *jsonData=[NSJSONSerialization dataWithJSONObject:propertyDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error){
        RCLogError([[NSString stringWithFormat:@"PushApiManager: createOrUpdateBinding ERROR: %@", error.description] UTF8String]);
        completionHandler(nil, [self getErrorWithDescription:@"Error creating JSON from bind object"]);
        return;
    }
    
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createOrUpdateBinding ERROR: %@", error.description] UTF8String]);
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        
        if (jsonError) {
            RCLogError([[NSString stringWithFormat:@"PushApiManager: createOrUpdateBinding ERROR: %@", jsonError.description] UTF8String]);
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing binding sid"]);
            return;
        }
        
        if (dict){
            RCBinding *rcBinding = [[RCBinding alloc]initWithDictionary:dict];
            RCLogInfo([[NSString stringWithFormat:@"PushApiManager: createOrUpdateBinding SUCCESS -> %@", rcBinding] UTF8String]);
            completionHandler(rcBinding, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}


- (NSError *)getErrorWithDescription:(NSString *)description{
    return  [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                       code:ERROR_PUSH_REGISTER
                                   userInfo:@{ NSLocalizedDescriptionKey: description}];
}


@end

