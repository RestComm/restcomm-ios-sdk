/*
 * libjingle
 * Copyright 2014 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "RTCICEServer+JSON.h"
#import "common.h"

static NSString const *kRTCICEServerUsernameKey = @"username";
static NSString const *kRTCICEServerPasswordKey = @"password";
static NSString const *kRTCICEServerUrisKey = @"uris";
static NSString const *kRTCICEServerUrlKey = @"urls";
static NSString const *kRTCICEServerCredentialKey = @"credential";

@implementation RTCIceServer (JSON)

+ (RTCIceServer *)serverFromJSONDictionary:(NSDictionary *)dictionary {
  NSString *url = dictionary[kRTCICEServerUrlKey];
  NSString *username = dictionary[kRTCICEServerUsernameKey];
  NSString *credential = dictionary[kRTCICEServerCredentialKey];
  username = username ? username : @"";
  credential = credential ? credential : @"";
  /*
  return [[RTCIceServer alloc] initWithURI:[NSURL URLWithString:url]
                                  username:username
                                  password:credential];
  */
  return [[RTCIceServer alloc] initWithURLStrings:[NSArray arrayWithObject:url]
                                    username:username
                                  credential:credential];
}

+ (NSArray *)serversFromCEODJSONDictionary:(NSDictionary *)dictionary {
  NSString *username = dictionary[kRTCICEServerUsernameKey];
  NSString *password = dictionary[kRTCICEServerPasswordKey];
  NSArray *uris = dictionary[kRTCICEServerUrisKey];
  NSMutableArray *servers = [NSMutableArray arrayWithCapacity:uris.count];
  for (NSString *uri in uris) {
      /*
      RTCIceServer *server =
        [[RTCIceServer alloc] initWithURI:[NSURL URLWithString:uri]
                                 username:username
                                 password:password];
       */
      RTCIceServer *server =
      [[RTCIceServer alloc] initWithURLStrings:[NSArray arrayWithObject:uri]
                                      username:username
                                    credential:password];

      [servers addObject:server];
  }
  return servers;
}

+ (NSArray *)serverFromXirsysArray:(NSArray *)array {
    NSMutableArray *iceServers = [[NSMutableArray alloc] init];
    for (NSDictionary *iceServerDictionary in array) {
        NSString *url = iceServerDictionary[@"url"];
        NSString *username = iceServerDictionary[@"username"];
        NSString *credential = iceServerDictionary[@"credential"];
        username = username ? username : @"";
        credential = credential ? credential : @"";
        RCLogNotice("[RTCIceServer serverFromXirsysArray] adding ICE server, url: %s, username: %s", [url UTF8String], [username UTF8String]);
        /*
        [iceServers addObject:[[RTCIceServer alloc] initWithURI:[NSURL URLWithString:url]
                                                       username:username
                                                       password:credential]];
         */
        [iceServers addObject:[[RTCIceServer alloc] initWithURLStrings:[NSArray arrayWithObject:url]
                                                              username:username
                                                            credential:credential]];
    }
    return iceServers;
}

@end
