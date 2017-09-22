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

#import "PushCommunicationManager.h"
#import "RestCommClient.h"
#import "common.h"

NSString *const kSignalingDomain = @"cloud.restcomm.com";
NSString *const kAccountSidUrl = @"/restcomm/2012-04-24/Accounts.json";
NSString *const kClientSidUrl = @"/restcomm/2012-04-24/Accounts";
NSString *const kPushDomain = @"push.restcomm.com/pushNotifications";

@implementation PushCommunicationManager{
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
        
        NSString *accountSid = [dict objectForKey:@"sid"];
        completionHandler(accountSid, nil);
        
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
                break;
            }
        }

    }] resume];
}


- (void)getApplicationSidwithCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler{
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
        if ([arr count] > 0){
            NSDictionary *dict = arr[0];
            NSString *applicationSid = [dict objectForKey:@"Sid"];
            completionHandler(applicationSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}


- (void)createApplicationWithFriendlyName:(NSString *)friendlyName withCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/applications", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [nameDictionary setObject:friendlyName forKey:@"FriendlyName"];
    
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
            NSString *applicationSid = [dict objectForKey:@"sid"];
            completionHandler(applicationSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}

- (void)createCredentialsWithCertificate:(NSString *)certificate privateKey:(NSString *)privateKey applicationSid:(NSString *)applicationSid friendlyName:(NSString *)friendlyName isSendBox:(BOOL)sendbox andCompletionHandler:(void (^)( NSString *credentialsSid, NSError *error))completionHandler{
    NSURL *url =  [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/credentials", kPushDomain]];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:url];
    
    NSMutableDictionary *nameDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [nameDictionary setObject:friendlyName forKey:@"ApplicationSid"];
    [nameDictionary setObject:certificate forKey:@"FriendlyName"];
    [nameDictionary setObject:@"apn" forKey:@"CredentialType"];
    [nameDictionary setObject:certificate forKey:@"Certificate"];
    [nameDictionary setObject:privateKey forKey:@"PrivateKey"];
    if (sendbox){
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
            NSString *credentialsSid = [dict objectForKey:@"sid"];
            completionHandler(credentialsSid, nil);
        } else {
            completionHandler(nil, nil);
        }
        
    }] resume];
}


- (void)updateBinding:(Binding *)binding forBindingSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSError *error))completionHandler{
    NSMutableURLRequest *request;// = [self createUrlRequestWithUrl:nil];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(error);
            return;
        }
        NSError *jsonError = nil;
        if (jsonError) {
            completionHandler([self getErrorWithDescription:@"Error parsing JSON containing account sid"]);
            return;
        }
        
        completionHandler(nil);
        
    }] resume];
}

- (void)createBinding:(Binding *)binding andCompletionHandler:(void (^)(NSError *error))completionHandler{
    NSMutableURLRequest *request;// = [self createUrlRequestWithUrl:nil];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completionHandler(error);
            return;
        }
        NSError *jsonError = nil;
        if (jsonError) {
            completionHandler([self getErrorWithDescription:@"Error parsing JSON containing account sid"]);
            return;
        }
        
        completionHandler(nil);
        
    }] resume];
}


- (NSString *) getJsonFromBinding:(Binding *)binding{
    NSDictionary *propertyDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Identity", binding.identity,
                              @"ApplicationSid", binding.applicationSid,
                              @"BindingType", binding.bindingType,
                              @"Address", binding.address,
                              nil];

    NSError *error;
    NSData *jsonData=[NSJSONSerialization dataWithJSONObject:propertyDictionary options:NSJSONWritingPrettyPrinted error:&error];
    
    if (error){
        RCLogError("Problem serializing Binding object");
        return nil;
    }
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
}

- (NSError *)getErrorWithDescription:(NSString *)description{
    return  [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                       code:ERROR_WEBRTC_TURN
                                   userInfo:@{ NSLocalizedDescriptionKey: description}];
}


@end
