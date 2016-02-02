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


#import "Utils.h"

@implementation Utils

NSString* const RestCommClientSDKLatestGitHash = @"255130e68c38e31f9d8740395150b394a7137eca";

+ (void) setupUserDefaults
{
    // DOC: very important. To add a NSDictionary or NSArray as part of NSUserDefaults the key must always be an NSString!
    NSDictionary *basicDefaults = @{
                                    @"placeholder-bool" : @YES,
                                    @"sip-identification" : @"sip:ios-sdk@cloud.restcomm.com",
                                    @"sip-password" : @"1234",
                                    @"sip-registrar" : @"",
                                    @"turn-url" : @"https://computeengineondemand.appspot.com/turn",
                                    @"turn-username" : @"iapprtc",
                                    @"turn-password" : @"4080218913",
                                    @"turn-candidate-timeout" : @"5",                                    @"contacts" :   // an array of contacts. Important: reason we use array is cause this is a backing store for a UITableView which suits it best due to its nature
                                    @[
                                        @[@"Play App", @"sip:+1234@cloud.restcomm.com"],
                                        @[@"Say App", @"sip:+1235@cloud.restcomm.com"],
                                        @[@"Gather App", @"sip:+1236@cloud.restcomm.com"],
                                        @[@"Conference Admin App", @"sip:+1311@cloud.restcomm.com"],
                                        @[@"Conference App", @"sip:+1310@cloud.restcomm.com"],
                                        ],
                                    @"chat-history" :   // a dictionary of chat histories (key is remote party full sip URI)
                                    @{
                                        @"sip:alice@cloud.restcomm.com" : @[
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
                                        @"sip:bob@cloud.restcomm.com" : @[
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

+ (NSArray*)messagesForSipUri:(NSString*)sipUri
{
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    if ([appDefaults dictionaryForKey:@"chat-history"] && [[appDefaults dictionaryForKey:@"chat-history"] objectForKey:sipUri]) {
        return [[appDefaults dictionaryForKey:@"chat-history"] objectForKey:sipUri];
    }
    return messages;
}

+ (void)addMessageForSipUri:(NSString*)sipUri text:(NSString*)text type:(NSString*)type
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray * aliasMessages = [[NSMutableArray alloc] init];
    if (![appDefaults dictionaryForKey:@"chat-history"]) {
        return;
    }
    
    NSMutableDictionary * messages = [[appDefaults dictionaryForKey:@"chat-history"] mutableCopy];
    if ([messages objectForKey:sipUri]) {
        aliasMessages = [[messages objectForKey:sipUri] mutableCopy];
    }
    
    [aliasMessages addObject:[NSDictionary dictionaryWithObjectsAndKeys:text, @"text", type, @"type", nil]];
    [messages setObject:aliasMessages forKey:sipUri];
    
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

/*
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
 */

+ (int)indexForContact:(NSString*)sipUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * contacts = [appDefaults arrayForKey:@"contacts"];
    
    for (int i = 0; i < [contacts count]; i++) {
        NSArray * contact = [contacts objectAtIndex:i];
        if ([[contact objectAtIndex:1] isEqualToString:sipUri]) {
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

+ (NSString*)turnUrl
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"turn-url"];
}

+ (NSString*)turnUsername
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"turn-username"];
}

+ (NSString*)turnPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"turn-password"];
}

+ (NSString*)turnCandidateTimeout
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"turn-candidate-timeout"];
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

+ (void)updateContactWithSipUri:(NSString*)sipUri alias:(NSString*)alias
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
        if ([[contact objectAtIndex:1] isEqualToString:sipUri]) {
            NSMutableArray * mutableContact = [contact mutableCopy];
            [mutableContact replaceObjectAtIndex:0 withObject:alias];
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

+ (void)updateTurnUrl:(NSString*)turnUrl
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnUrl forKey:@"turn-url"];
}

+ (void)updateTurnUsername:(NSString*)turnUsername
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnUsername forKey:@"turn-username"];
}

+ (void)updateTurnPassword:(NSString*)turnPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnPassword forKey:@"turn-password"];
}

+ (void)updateTurnCandidateTimeout:(NSString*)turnCandidateTimeout
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnCandidateTimeout forKey:@"turn-candidate-timeout"];
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
