//
//  RCPresenceEvent.h
//  RestCommClient
//
//  Created by Antonis Tsakiridis on 7/13/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RCPresenceEvent : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly, getter = isAvailable) BOOL available;

@end
