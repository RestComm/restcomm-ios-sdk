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
#import "RCUtilities.h"

@implementation Utils

NSString* const RestCommClientSDKLatestGitHash = @"255130e68c38e31f9d8740395150b394a7137eca";

+ (void) setupUserDefaults
{
    // DOC: very important. To add a NSDictionary or NSArray as part of NSUserDefaults the key must always be an NSString!
    NSDictionary *basicDefaults = @{
                                    @"is-first-time" : @(YES),
                                    @"pending-interapp-uri" : @"",  // has another app sent us a URL to call?
                                    @"sip-identification" : @"",  //@"sip:ios-sdk@cloud.restcomm.com",
                                    @"sip-password" : @"",
                                    @"sip-registrar" : @"cloud.restcomm.com",
                                    @"turn-enabled" : @(YES),
                                    @"turn-url" : @"https://service.xirsys.com/ice",  // @"https://computeengineondemand.appspot.com/turn",
                                    @"turn-username" : @"atsakiridis",  // @"iapprtc",
                                    @"turn-password" : @"4e89a09e-bf6f-11e5-a15c-69ffdcc2b8a7",  // @"4080218913"
                                    @"signaling-secure" : @(YES),  // by default signaling is secure
                                    @"signaling-certificate-dir" : @"",
                                    //@"turn-candidate-timeout" : @"5",
                                    @"contacts" :   // an array of contacts. Important: reason we use array is cause this is a backing store for a UITableView which suits it best due to its nature
                                    @[
                                        @[@"Play App", @"+1234"],  //@"sip:+1234@cloud.restcomm.com"],
                                        @[@"Say App", @"+1235"],  //@"sip:+1235@cloud.restcomm.com"],
                                        @[@"Gather App", @"+1236"],  //@"sip:+1236@cloud.restcomm.com"],
                                        @[@"Conference Admin App", @"+1311"],  //@"sip:+1311@cloud.restcomm.com"],
                                        @[@"Conference App", @"+1310"],  //@"sip:+1310@cloud.restcomm.com"],
                                        ],
                                    @"chat-history" :   // a dictionary of chat histories (key is remote party full sip URI)
                                    @{
                                        @"alice" : @[  //@"sip:alice@cloud.restcomm.com" : @[
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
                                        @"bob" : @[  //@"sip:bob@cloud.restcomm.com" : @[
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

+ (NSString*)sipUri2Alias:(NSString*)sipUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSArray * contacts = [appDefaults arrayForKey:@"contacts"];

    for (int i = 0; i < [contacts count]; i++) {
        NSArray * contact = [contacts objectAtIndex:i];
        if ([[contact objectAtIndex:1] isEqualToString:sipUri]) {
            return [contact objectAtIndex:0];
        }
    }

    return @"";
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

+ (BOOL)turnEnabled
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:@"turn-enabled"] boolValue];
}

+ (BOOL)signalingSecure
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:@"signaling-secure"] boolValue];
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

+ (BOOL)isFirstTime
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:@"is-first-time"] boolValue];
}

+ (NSString*)pendingInterappUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:@"pending-interapp-uri"];
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

+ (void)updateTurnEnabled:(BOOL)turnEnabled
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:@(turnEnabled) forKey:@"turn-enabled"];
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

+ (void)updateIsFirstTime:(BOOL)isFirstTime
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:[NSNumber numberWithBool:isFirstTime] forKey:@"is-first-time"];
}

+ (void)updatePendingInterappUri:(NSString*)uri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:uri forKey:@"pending-interapp-uri"];
}

+ (void)updateSignalingSecure:(BOOL)signalingSecure
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:@(signalingSecure) forKey:@"signaling-secure"];
}

+ (NSString*)convertInterappUri2RestcommUri:(NSURL*)uri
{
    /* Here are the possible URLs we need to handle here:
     * sip://bob@telestax.com
     * restcomm-sip://bob@telestax.com
     * tel://+1235
     * restcomm-tel://+1235@telestax.com
     * client://bob
     * restcomm-client://bob
     * restcomm-app://bob -> just opens app and potentially login with user
     * Important note: the browser only recognizes URLs starting with 'scheme://', not 'scheme:'
     */

    //NSLog(@"convertInterappUri2RestcommUri URL scheme:%@", [uri scheme]);
    //NSLog(@"convertInterappUri2RestcommUri URL host:%@", [uri host]);
    //NSLog(@"convertInterappUri2RestcommUri URL query: %@", [uri query]);
    NSLog(@"convertInterappUri2RestcommUri URL absolute string: %@", [uri absoluteString]);

    NSString * final = nil;
    if ([RCUtilities string:[uri scheme] containsString:@"sip"]) {
        // either 'sip' or 'restcomm-sip'
        // normalize 'restcomm-sip' and replace with 'sip'
        NSString * normalized = [[uri absoluteString] stringByReplacingOccurrencesOfString:@"restcomm-sip" withString:@"sip"];
        // also replace '://' with ':' so that the SIP stack can understand it
        final = [normalized stringByReplacingOccurrencesOfString:@"://" withString:@":"];
    } else if ([RCUtilities string:[uri scheme] containsString:@"app"]) {
        //just open the app with no call initiated
    }
    else {
        // either 'tel', 'restcomm-tel', 'client' or 'restcomm-client'. Return just the host part, like 'bob' or '1235' that the Restcomm SDK can handle
        final = [NSString stringWithFormat:@"%@", [uri host]];
    }

    NSLog(@"convertInterappUri2RestcommUri after conversion: %@", final);
    return final;
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
