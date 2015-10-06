//
//  Utilities.m
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 9/11/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "Utilities.h"
#import "common.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"


@implementation Utilities

+ (NSString*)usernameFromUri:(NSString*)uri
{
    NSString* schemaUsername = nil;
    NSString* username = nil;
    if ([uri rangeOfString:@"@"].location != NSNotFound) {
        schemaUsername = [uri componentsSeparatedByString:@"@"][0];
        if (schemaUsername && [schemaUsername rangeOfString:@":"].location != NSNotFound) {
            username = [schemaUsername componentsSeparatedByString:@":"][1];
        }
    }
    else {
        username = uri;
    }
    return username;
}

+ (NSString*)stringifyDictionary:(NSDictionary*)dictionary
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error) {
        RCLogError("[Utilities stringifyDictionary] Error");
        return @"";
    }

    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

+ (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if (!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

// primary address is the one we want to be used based on charging. For example if both wifi & cellular network
// are available we want to use wifi
+ (NSString *)getPrimaryIPAddress
{
    NSDictionary * addresses = [Utilities getIPAddresses];
    // prefer wifi over cellular. TODO: need to add ipv6 logic if we want to support it
    NSArray * preference = @[IOS_WIFI@"/"IP_ADDR_IPv4, IOS_CELLULAR@"/"IP_ADDR_IPv4];
    
    /*
    NSString * key = IOS_WIFI@"/"IP_ADDR_IPv4;
    if ([addresses objectForKey:key]) {
        return [addresses objectForKey:key];
    }

    key = IOS_CELLULAR@"/"IP_ADDR_IPv4;
    if ([addresses objectForKey:key]) {
        return [addresses objectForKey:key];
    }
    
    return @"";
     */

    /**/
    for (NSString * key in preference) {
        if ([addresses objectForKey:key]) {
            return [addresses objectForKey:key];
        }
    }
    return @"";
}

@end
