//
//  Utils.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "Utils.h"

@implementation Utils

+ (void) setupUserDefaults
{
    // DOC: very important. To add a NSDictionary or NSArray as part of NSUserDefaults the key must always be an NSString!
    NSDictionary *basicDefaults = @{
                                    @"placeholder-bool" : @YES,
                                    @"sip-identification" : @"sip:bob@telestax.com",
                                    @"sip-password" : @"1234",
                                    @"sip-registrar" : @"23.23.228.238:5080",
                                    @"contacts" :   // an array of contacts
                                    @[
                                        @[@"Alice", @"sip:alice@telestax.com:5080"],
                                        @[@"Bob", @"sip:bob@telestax.com:5080"],
                                        @[@"Hello World App", @"sip:1235@telestax.com:5080"],
                                        @[@"Conference App", @"sip:1311@telestax.com:5080"],
                                        @[@"Team Call", @"sip:+5126001502@telestax.com:5080"],
                                        ],
                                    @"chat-history" :   // a dictionary of chat histories (key is remote party full sip URI)
                                    @{
                                        @"Alice" : @[
                                                @{
                                                    @"text" : @"Hello Alice",
                                                    @"type" : @"local",
                                                    },
                                                @{
                                                    @"text" : @"Hello",
                                                    @"type" : @"remote",
                                                    },
                                                @{
                                                    @"text" : @"What's up?",
                                                    @"type" : @"local",
                                                    },
                                                ],
                                        @"Bob" : @[
                                                @{
                                                    @"text" : @"Is Bob around?",
                                                    @"type" : @"local",
                                                    },
                                                @{
                                                    @"text" : @"Yes, I'm here",
                                                    @"type" : @"remote",
                                                    },
                                                @{
                                                    @"text" : @"Great",
                                                    @"type" : @"local",
                                                    },
                                                ],
                                        },
                                    };
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:basicDefaults];
}

+ (NSArray*)messagesForAlias:(NSString*)alias
{
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    if ([appDefaults dictionaryForKey:@"chat-history"] && [[appDefaults dictionaryForKey:@"chat-history"] objectForKey:alias]) {
        return [[appDefaults dictionaryForKey:@"chat-history"] objectForKey:alias];
    }
    return messages;
}

+ (void)addMessageForAlias:(NSString*)alias text:(NSString*)text type:(NSString*)type
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray * aliasMessages = [[NSMutableArray alloc] init];
    if (![appDefaults dictionaryForKey:@"chat-history"]) {
        return;
    }
    
    NSMutableDictionary * messages = [[appDefaults dictionaryForKey:@"chat-history"] mutableCopy];
    if ([messages objectForKey:alias]) {
        aliasMessages = [[messages objectForKey:alias] mutableCopy];
    }
    
    [aliasMessages addObject:[NSDictionary dictionaryWithObjectsAndKeys:text, @"text", type, @"type", nil]];
    [messages setObject:aliasMessages forKey:alias];
    
    [appDefaults setObject:messages forKey:@"chat-history"];
}

+ (NSArray*)contactForIndex:(int)index
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * contacts = [appDefaults arrayForKey:@"contacts"];
    if (contacts) {
        if ([contacts count] > index) {
            return [contacts objectAtIndex:index];
        }
    }
    return nil;
}

+ (int)indexForContact:(NSString*)alias
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * contacts = [appDefaults arrayForKey:@"contacts"];
    
    for (int i = 0; i < [contacts count]; i++) {
        NSArray * contact = [contacts objectAtIndex:i];
        if ([[contact objectAtIndex:0] isEqualToString:alias]) {
            return i;
        }
    }

    return -1;
}

+ (NSString*)sipIdentification
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"sip-identification"];
}

+ (NSString*)sipPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"sip-password"];
}

+ (NSString*)sipRegistrar
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"sip-registrar"];
}

+ (int)contactCount
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * contacts = [appDefaults arrayForKey:@"contacts"];
    if (contacts) {
        return [contacts count];
    }
    return 0;
}

/*
+ (NSString*) genericType:(NSString*)type forLevel:(NSNumber*)level;
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    
    if ([appDefaults dictionaryForKey:type]) {
        if([[appDefaults dictionaryForKey:type] objectForKey:[level stringValue]]) {
            return [[[appDefaults dictionaryForKey:type] objectForKey:[level stringValue]] stringValue];
        }
    }
    return @"0";
}
 */


+ (void)addContact:(NSArray*)contact
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray * mutable = nil;
    if ([appDefaults arrayForKey:@"contacts"]) {
        // exists; get a mutable copy
        mutable = [[appDefaults arrayForKey:@"contacts"] mutableCopy];
    }
    else {
        // should never happen
        return;
    }
    
    [mutable addObject:contact];
    
    // update user defaults
    [appDefaults setObject:mutable forKey:@"contacts"];
}

+ (void)removeContactAtIndex:(int)index
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray * mutable = nil;
    if ([appDefaults arrayForKey:@"contacts"]) {
        // exists; get a mutable copy
        mutable = [[appDefaults arrayForKey:@"contacts"] mutableCopy];
    }
    else {
        // should never happen
        return;
    }
    
    [mutable removeObjectAtIndex:index];
    
    // update user defaults
    [appDefaults setObject:mutable forKey:@"contacts"];
}

+ (void)updateContactWithAlias:(NSString*)alias sipUri:(NSString*)sipUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray * mutable = nil;
    if ([appDefaults arrayForKey:@"contacts"]) {
        // exists; get a mutable copy
        mutable = [[appDefaults arrayForKey:@"contacts"] mutableCopy];
    }
    else {
        // should never happen
        return;
    }
    
    for (int i = 0; i < [mutable count]; i++) {
        NSArray * contact = [mutable objectAtIndex:i];
        if ([[contact objectAtIndex:0] isEqualToString:alias]) {
            NSMutableArray * mutableContact = [contact mutableCopy];
            [mutableContact replaceObjectAtIndex:1 withObject:sipUri];
            [mutable replaceObjectAtIndex:i withObject:mutableContact];
        }
    }

    // update user defaults
    [appDefaults setObject:mutable forKey:@"contacts"];
}

+ (void)updateSipIdentification:(NSString*)sipIdentification
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipIdentification forKey:@"sip-identification"];
}

+ (void)updateSipPassword:(NSString*)sipPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipPassword forKey:@"sip-password"];
}

+ (void)updateSipRegistrar:(NSString*)sipRegistrar
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipRegistrar forKey:@"sip-registrar"];
}


/*
+ (void) setGenericType:(NSString*)type forLevel:(NSNumber*)level withValue:(NSNumber*)value updateType:(NSString*)updateType
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableDictionary * mutable = nil;
    if ([appDefaults dictionaryForKey:type]) {
        // exists; get a mutable copy
        mutable = [[appDefaults dictionaryForKey:type] mutableCopy];
    }
    else {
        // if the type does not exist create it
        mutable = [[NSMutableDictionary alloc] init];
    }
    
    BOOL updateValue = YES;
    if (updateType && [updateType isEqualToString:@"update-when-greater"]) {
        // if there's a value for the level score or stars and that is bigger than the current value then don't update score
        if ([mutable objectForKey:[level stringValue]] && ([value intValue] < [[mutable objectForKey:[level stringValue]] intValue])) {
            updateValue = NO;
        }
    }
    
    if (updateValue) {
        [mutable setObject:value forKey:[level stringValue]];
    }
    
    // update user defaults
    [appDefaults setObject:mutable forKey:type];
}
 */

@end
