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
NSString *const kPushDomain = @"push.restcomm.com/pushNotifications";

//NSString *const kSignalingDomain = @"staging.restcomm.com";
//NSString *const kAccountSidUrl = @"/restcomm/2012-04-24/Accounts.json";
//NSString *const kClientSidUrl = @"/restcomm/2012-04-24/Accounts";
//NSString *const kPushDomain = @"staging.restcomm.com/push";


@implementation PushApiManager{
    NSString *pUsername;
    NSString *pPassword;
    NSURLSession *session;
}


- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password{
    self = [super init];
    if (self){
        pUsername = username;
        pPassword = password;
        session = [NSURLSession sharedSession];
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
    
    
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing account sid"]);
            return;
        }
        
        if (dict){
            NSString *accountSid = [dict objectForKey:@"sid"];
            completionHandler(accountSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
        
    }] resume];
}

- (void)getClientSidWithAccountSid:(NSString *)accountSid signalingUsername:(NSString *)signalingUsername andCompletionHandler:(void (^)( NSString *clientSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@/%@/Clients.json", kSignalingDomain, kClientSidUrl, accountSid]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing client sid"]);
            return;
        }
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i<arr.count; i ++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"login"] isEqualToString:signalingUsername]){
                NSString *clientSid = [dict objectForKey:@"sid"];
                completionHandler(clientSid, nil);
                return;
                
            }
        }
        completionHandler(nil, nil);
    }] resume];
}


- (void)getApplicationSidForFriendlyName:(NSString *)friendlyName withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/applications", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing application sid"]);
            return;
        }
        
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i<arr.count; i ++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"FriendlyName"] isEqualToString:friendlyName]){
                NSString *applicationSid = [dict objectForKey:@"Sid"];
                completionHandler(applicationSid, nil);
                return;
            }
        }
        completionHandler(nil, nil);
        
        
    }] resume];
}

- (void)getCredentialsSidWithCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/credentials", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing credentials sid"]);
            return;
        }
        
        NSArray *arr = (NSArray *)jsonArray;
        for (int i=0; i< arr.count; i++){
            NSDictionary *dict = arr[i];
            if ([[dict objectForKey:@"CredentialType"] isEqualToString:@"apn"]){
                NSString *applicationSid = [dict objectForKey:@"Sid"];
                completionHandler(applicationSid, nil);
                return;
            }
        }
        completionHandler(nil, nil);
        
        
    }] resume];
}


- (void)createApplicationWithFriendlyName:(NSString *)friendlyName isSendbox:(BOOL)isSendbox withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/applications", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [nameDictionary setObject:friendlyName forKey:@"FriendlyName"];
    if (isSendbox){
        [nameDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"Sandbox"];
    }
    
    NSError *jsonSerializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nameDictionary options:NSJSONWritingPrettyPrinted error:&jsonSerializationError];
    
    if (jsonSerializationError){
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
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing application sid"]);
            return;
        }
        
        if (dict){
            NSString *applicationSid = [dict objectForKey:@"Sid"];
            completionHandler(applicationSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}

- (void)createCredentialsWithCertificate:(NSString *)certificate privateKey:(NSString *)privateKey applicationSid:(NSString *)applicationSid friendlyName:(NSString *)friendlyName andCompletionHandler:(void (^)(NSString *credentialsSid, NSError *error))completionHandler{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/credentials", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [nameDictionary setObject:applicationSid forKey:@"ApplicationSid"];
    [nameDictionary setObject:friendlyName forKey:@"FriendlyName"];
    [nameDictionary setObject:@"apn" forKey:@"CredentialType"];
    [nameDictionary setObject:certificate forKey:@"Certificate"];
    [nameDictionary setObject:privateKey forKey:@"PrivateKey"];
    
    NSError *jsonSerializationError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:nameDictionary options:NSJSONWritingPrettyPrinted error:&jsonSerializationError];
    
    if (jsonSerializationError){
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
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing credentials sid"]);
            return;
        }
        
        if (dict){
            NSString *credentialsSid = [dict objectForKey:@"Sid"];
            completionHandler(credentialsSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}


- (void)checkExistingBindingSidWithCompletionHandler:(void (^)(NSString *bindingSid, NSString *savedTokenOnServer, NSError *error))completionHandler{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/bindings", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSObject *jsonArray = [NSJSONSerialization JSONObjectWithData:data
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
        if (jsonError) {
            completionHandler(nil, nil, [self getErrorWithDescription:@"Error parsing JSON containing binding sid"]);
            return;
        }
        
        if (jsonArray){
            //chek to see if user have already sid for Binding type apn
            NSArray *arr = (NSArray *)jsonArray;
            for (int i=0; i< arr.count; i++){
                NSDictionary *dict = arr[i];
                if ([[dict objectForKey:@"BindingType"] isEqualToString:@"apn"]){
                    NSString *bindingSid = [dict objectForKey:@"Sid"];
                    NSString *savedTokenOnServer = [dict objectForKey:@"Address"];
                    completionHandler(bindingSid, savedTokenOnServer, nil);
                    return;
                }
            }
        } else {
            completionHandler(nil, nil, nil);
        }
    }] resume];
}

- (void)createBinding:(Binding *)binding andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler{
    [self createOrUpdateBinding:binding forSid:nil andCompletionHandler:completionHandler];
}

- (void)updateBinding:(Binding *)binding forBindingSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler{
    [self createOrUpdateBinding:binding forSid:bindingSid andCompletionHandler:completionHandler];
}

- (void)createOrUpdateBinding:(Binding *)binding forSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSString *bindingSid, NSError *error))completionHandler{
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/bindings", kPushDomain]];
    if (bindingSid){
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/bindings/%@", kPushDomain, bindingSid]];
    }
    
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    if (bindingSid){
        [request setHTTPMethod:@"PUT"];
    } else {
        [request setHTTPMethod:@"POST"];
    }
    
    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [propertyDictionary setObject:binding.clientSid forKey:@"Identity"];
    [propertyDictionary setObject:binding.applicationSid forKey:@"ApplicationSid"];
    [propertyDictionary setObject:binding.bindingType forKey:@"BindingType"];
    [propertyDictionary setObject:binding.address forKey:@"Address"];
    
    
    NSError *error;
    NSData *jsonData=[NSJSONSerialization dataWithJSONObject:propertyDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error){
        completionHandler(nil, [self getErrorWithDescription:@"Error creating JSON from bind object"]);
        return;
    }
    
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (long)[jsonData length]] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody: jsonData];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(nil, error);
            return;
        }
        NSError *jsonError = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                             options:NSJSONReadingMutableContainers
                                                               error:&jsonError];
        
        if (jsonError) {
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing binding sid"]);
            return;
        }
        
        if (dict){
            NSString *bindingSid = [dict objectForKey:@"Sid"];
            completionHandler(bindingSid, nil);
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

