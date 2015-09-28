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
//+ (int)indexForContact:(NSString*)alias;
// if contact is not found returns -1
+ (int)indexForContact:(NSString*)sipUri;
+ (int)contactCount;
+ (void)addContact:(NSArray*)contact;
+ (void)removeContactAtIndex:(int)index;
+ (void)updateContactWithSipUri:(NSString*)sipUri alias:(NSString*)alias;
+ (NSString*)sipIdentification;
+ (NSString*)sipPassword;
+ (NSString*)sipRegistrar;
+ (void)updateSipIdentification:(NSString*)sipIdentification;
+ (void)updateSipPassword:(NSString*)sipPassword;
+ (void)updateSipRegistrar:(NSString*)sipRegistrar;
// return messages in the format understood by MessageTableViewController
+ (NSArray*)messagesForSipUri:(NSString*)sipUri;
+ (void)addMessageForSipUri:(NSString*)sipUri text:(NSString*)text type:(NSString*)type;
@end
