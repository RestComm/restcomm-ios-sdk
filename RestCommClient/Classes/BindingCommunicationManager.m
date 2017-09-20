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

#import "BindingCommunicationManager.h"
#import "RestCommClient.h"
#import "common.h"

@implementation BindingCommunicationManager{
    NSString *pUsername;
    NSString *pPassword;
}


- (id)initWithUsername:(NSString *)username andPassword:(NSString *)password{
    self = [super init];
    if (self){
        pUsername = username;
        pPassword = password;
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


- (void)getAccountSidWithRequestWidthCompletionHandler:(void (^)( NSString *accountSid, NSError *error))completionHandler{
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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

- (void)getClientSidWithAccountSid:(NSString *)accountSid andCompletionHandler:(void (^)( NSString *clientSid, NSError *error))completionHandler{
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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
            completionHandler(nil, [self getErrorWithDescription:@"Error parsing JSON containing client sid"]);
            return;
        }
        
        NSString *clientSid = [dict objectForKey:@"sid"];
        completionHandler(clientSid, nil);
        
    }] resume];
}


- (void)getApplicationSidwithCompletionHandler:(void (^)( NSString *applicationSid, NSError *error))completionHandler{
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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
        
        NSString *applicationSid = [dict objectForKey:@"sid"];
        completionHandler(applicationSid, nil);
        
    }] resume];
}



- (void)getBindingSidForBinding:(Binding *)binding andCompletionHandler:(void (^)( NSString *bindingSid, NSError *error))completionHandler{
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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

- (void)updateBinding:(Binding *)binding forBindingSid:(NSString *)bindingSid andCompletionHandler:(void (^)(NSError *error))completionHandler{
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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
    NSURLSession *session = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [self createUrlRequestWithUrl:nil];
    
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
