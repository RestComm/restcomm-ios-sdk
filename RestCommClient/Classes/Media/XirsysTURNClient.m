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


#import "XirsysTURNClient.h"

#import "ARDUtilities.h"
#import "RTCICEServer+JSON.h"
#import "RestCommClient.h"


@interface XirsysTURNClient ()
@property NSURL * url;
@end

@implementation XirsysTURNClient

- (instancetype)initWithURL:(NSURL *)url {
    NSParameterAssert([url absoluteString].length);
    if (self = [super init]) {
        _url = url;
    }
    return self;
}

- (void)requestServersWithCompletionHandler:(void (^)(NSArray *turnServers, NSError *error))completionHandler
{
    //NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
    // We need to set origin because TURN provider whitelists requests based on
    // origin.
    //[request addValue:@"Mozilla/5.0" forHTTPHeaderField:@"user-agent"];
    //[request addValue:kTURNOriginURLString forHTTPHeaderField:@"origin"];
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:_url
            completionHandler:^(NSData *data,
                                NSURLResponse *response,
                                NSError *error) {
                NSArray *turnServers = [NSArray array];
                if (error) {
                    completionHandler(turnServers, error);
                    return;
                }
                NSError *jsonError = nil;
                //NSDictionary *ss = [NSDictionary dictionaryWithJSONData:data];
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:NSJSONReadingMutableContainers
                                                                       error:&jsonError];
                if (jsonError) {
                    NSError *responseError =
                    [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                               code:ERROR_WEBRTC_TURN
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error parsing JSON containing TURN servers. Check your TURN service"],
                                                      }];
                    completionHandler(turnServers, responseError);
                    return;
                }
                
                NSNumber * status = [dict objectForKey:@"s"];
                if ([status integerValue] != 200) {
                    NSError *responseError =
                    [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                               code:ERROR_WEBRTC_TURN
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error retrieving TURN servers: %@. Check your TURN service or disable TURN altogether", [dict objectForKey:@"e"]],
                                                      }];
                    completionHandler(turnServers, responseError);
                    return;
                }
                
                NSArray * iceServers = [[dict objectForKey:@"d"] objectForKey:@"iceServers"];
                //turnServers = [RTCICEServer serversFromCEODJSONDictionary:dict];
                
                turnServers = [RTCIceServer serverFromXirsysArray:iceServers];
                if (!turnServers) {
                    NSError *responseError =
                    [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                     // TODO: update error code once I get this working
                                               code:100
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Bad TURN response.",
                                                      }];
                    completionHandler(turnServers, responseError);
                    return;
                }
                completionHandler(turnServers, nil);
                
            }] resume];
    
    /*
    [NSURLConnection sendAsyncRequest:request
                    completionHandler:^(NSURLResponse *response,
                                        NSData *data,
                                        NSError *error) {
                        NSArray *turnServers = [NSArray array];
                        if (error) {
                            completionHandler(turnServers, error);
                            return;
                        }
                        NSDictionary *dict = [NSDictionary dictionaryWithJSONData:data];
                        NSNumber * status = [dict objectForKey:@"s"];
                        if ([status integerValue] != 200) {
                            NSError *responseError =
                            [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                       code:ERROR_WEBRTC_TURN
                                                   userInfo:@{
                                                              NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error retrieving TURN servers: %@. Check your TURN service or disable TURN altogether", [dict objectForKey:@"e"]],
                                                              }];
                            completionHandler(turnServers, responseError);
                            return;
                        }
                        
                        NSArray * iceServers = [[dict objectForKey:@"d"] objectForKey:@"iceServers"];
                        //turnServers = [RTCICEServer serversFromCEODJSONDictionary:dict];
                        
                        turnServers = [RTCIceServer serverFromXirsysArray:iceServers];
                        if (!turnServers) {
                            NSError *responseError =
                            [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                    // TODO: update error code once I get this working
                                                       code:100
                                                   userInfo:@{
                                                              NSLocalizedDescriptionKey: @"Bad TURN response.",
                                                              }];
                            completionHandler(turnServers, responseError);
                            return;
                        }
                        completionHandler(turnServers, nil);
                    }];
     */
}

@end
