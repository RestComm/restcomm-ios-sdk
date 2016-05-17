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

#import "RCUtilities.h"
#import "common.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#define IOS_CELLULAR            @"pdp_ip0"
#define WIFI                    @"en0"   // iOS or OSX (simulator)
#define ETH_OVER_THUNDERBOLT    @"en4"   // OSX
#define IOS_VPN                 @"utun0"
#define IP_ADDR_IPv4            @"ipv4"
#define IP_ADDR_IPv6            @"ipv6"


@implementation RCUtilities

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
    if (dictionary == nil) {
        return @"";
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (error) {
        RCLogError("[RCUtilities stringifyDictionary] Error");
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
    NSDictionary * addresses = [RCUtilities getIPAddresses];
    // prefer wifi over cellular. TODO: need to add ipv6 logic if we want to support it
    NSArray * preference = @[WIFI@"/"IP_ADDR_IPv4, ETH_OVER_THUNDERBOLT@"/"IP_ADDR_IPv4, IOS_CELLULAR@"/"IP_ADDR_IPv4];
    
    for (NSString * key in preference) {
        if ([addresses objectForKey:key]) {
            return [addresses objectForKey:key];
        }
    }
    return @"";
}

// Helper to implement containsString for iOS 7.0 as well
+ (BOOL)string:(NSString*)string containsString:(NSString*)containedString
{
    NSRange range = [string rangeOfString:containedString];
    return range.length != 0;
}

@end
