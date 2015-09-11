//
//  Utilities.m
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 9/11/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "Utilities.h"

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

@end
