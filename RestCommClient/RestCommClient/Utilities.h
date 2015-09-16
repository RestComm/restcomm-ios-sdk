//
//  Utilities.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 9/11/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utilities : NSObject
+ (NSString*)usernameFromUri:(NSString*)uri;
+ (NSString*)stringifyDictionary:(NSDictionary*)dictionary;
@end
