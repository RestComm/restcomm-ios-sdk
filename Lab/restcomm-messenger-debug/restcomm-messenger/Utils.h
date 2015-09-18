//
//  Utils.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Utils : NSObject
+ (void) setupUserDefaults;
+ (NSArray*)contactForIndex:(int)index;
+ (int)indexForContact:(NSString*)alias;
+ (int)contactCount;
+ (void)addContact:(NSArray*)contact;
+ (void)updateContactWithAlias:(NSString*)contact sipUri:(NSString*)sipUri;
+ (NSString*)sipIdentification;
+ (NSString*)sipPassword;
+ (NSString*)sipRegistrar;
+ (void)updateSipIdentification:(NSString*)sipIdentification;
+ (void)updateSipPassword:(NSString*)sipPassword;
+ (void)updateSipRegistrar:(NSString*)sipRegistrar;
@end
