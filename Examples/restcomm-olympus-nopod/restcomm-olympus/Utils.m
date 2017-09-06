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

NSString* const RestCommClientSDKLatestGitHash = @"#GIT-HASH";

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
                                    @"contacts" : [NSKeyedArchiver archivedDataWithRootObject:[Utils getDefaultContacts]],
                                    @"chat-history" : [Utils getDefaultChatHistory], // a dictionary of chat histories (key is remote party full sip URI)
                                    };
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:basicDefaults];
}

#pragma mark - Contacts

+ (LocalContact *)contactForIndex:(int)index
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            if ([filterdArray count] > index) {
                return [filterdArray objectAtIndex:index];
           }
        } else {
            // should never happen
            return nil;
        }
    } else {
        // should never happen
        return nil;
    }
    return nil;
}


+ (int)indexForContact:(NSString*)sipUri
{
    //index for contact is only for filtered array (non deleted contacts)
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
           NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                LocalContact *localContact = [filterdArray objectAtIndex:i];
                
                //Phone numbers
                if (localContact.phoneNumbers && localContact.phoneNumbers.count > 0){
                    for (int j=0; j < localContact.phoneNumbers.count; j++){
                        if ([localContact.phoneNumbers[j] isEqualToString:sipUri]){
                            return i;
                        }
                    }
                }
            }
        } else {
            // should never happen
            return -1;
        }
    } else {
        // should never happen
        return -1;
    }
    
    return -1;
}

+ (NSString*)sipUri2Alias:(NSString*)sipUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
   
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                LocalContact *localContact = [filterdArray objectAtIndex:i];
                
                //Phone numbers
                if (localContact.phoneNumbers && localContact.phoneNumbers.count > 0){
                    for (int j=0; j < localContact.phoneNumbers.count; j++){
                        if ([localContact.phoneNumbers[j] isEqualToString:sipUri]){
                            return [NSString stringWithFormat:@"%@ %@", localContact.firstName, localContact.lastName];
                        }
                    }
                }
            }
        } else {
            // should never happen
            return @"";
        }
    } else {
        // should never happen
        return @"";
    }
    return @"";
}

+ (int)contactCount
{
    NSData *contactsArrayData = [[NSUserDefaults standardUserDefaults] objectForKey:@"contacts"];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            //return non deleted contacts
            NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            return (int)[filterdArray count];
        }
    }
    return 0;
}


+ (void)addContact:(LocalContact *)contact
{
    NSUserDefaults *appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray * mutable = nil;
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            mutable = [contactsArray mutableCopy];
        } else {
            // should never happen
            return;
        }
    } else {
        // should never happen
        return;
    }
    BOOL exists = NO;
    //check if object is already added
    for (int i=0; i < mutable.count; i ++){
        LocalContact *savedContact = mutable[i];
        if ([savedContact isEqual:contact]){
            exists = YES;
            break;
        }
    }
    
    if (!exists){
        [mutable addObject:contact];
    }
    
    // update user defaults
    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:@"contacts"];
}

+ (void)removeContactAtIndex:(int)index
{
    //contact will have the flag deleted set to true
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray * mutable = nil;
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
    
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            LocalContact *localContact = [filterdArray objectAtIndex:index];
            
            mutable = [contactsArray mutableCopy];
            for (int i=0; i<mutable.count; i ++){
                LocalContact *fromNonFilteredContact = [mutable objectAtIndex:i];
                if ([fromNonFilteredContact isEqual:localContact]){
                    fromNonFilteredContact.deleted = YES;
                    // update user defaults
                    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:@"contacts"];
                    break;
                }
            }
        } else {
            // should never happen
            return;
        }
    } else {
        // should never happen
        return;
    }
    
    
}

+ (void)updateContactWithSipUri:(NSString*)sipUri alias:(NSString*)alias
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:@"contacts"];
    
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                LocalContact *localContact = [filterdArray objectAtIndex:i];
                
                if (localContact.phoneNumbers && localContact.phoneNumbers.count > 0){
                    //phone numbers (sip uris)
                    for (int j=0; j < localContact.phoneNumbers.count; j++){
                        if ([localContact.phoneNumbers[j] isEqualToString:sipUri]){
                            //update the actual object in non predicated array
                            NSMutableArray *mutable = [contactsArray mutableCopy];
                            
                            for (int z=0; y<mutable.count; z ++){
                                LocalContact *fromNonFilteredContact = [mutable objectAtIndex:z];
                                if ([fromNonFilteredContact isEqual:localContact]){
                                    localContact.firstName = alias;
                                    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:@"contacts"];
                                    return;
                                }
                            }
                        }
                    }
                }
            }
        }else {
            // should never happen
            return;
        }
    }else {
        // should never happen
        return;
    }
    
}

#pragma mark - Messages

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

#pragma mark - SIP

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
    }
    else {
        // either 'tel', 'restcomm-tel', 'client' or 'restcomm-client'. Return just the host part, like 'bob' or '1235' that the Restcomm SDK can handle
        final = [NSString stringWithFormat:@"%@", [uri host]];
    }
    
    NSLog(@"convertInterappUri2RestcommUri after conversion: %@", final);
    return final;
}

#pragma mark - Default values

+ (NSArray *)getDefaultContacts{

    
    LocalContact *localContactPlayApp = [[LocalContact alloc] initWithFirstName:@"Play" lastName:@"App" andPhoneNumbers:@[@"+1234"]]; //@"sip:+1234@cloud.restcomm.com"],
    LocalContact *localContactSayApp = [[LocalContact alloc] initWithFirstName:@"Say" lastName:@"App" andPhoneNumbers:@[@"+1235"]]; //@"sip:+1235@cloud.restcomm.com"],
    LocalContact *localContactGatherApp = [[LocalContact alloc] initWithFirstName:@"Gather" lastName:@"App" andPhoneNumbers:@[@"+1236"]]; //@"sip:+1236@cloud.restcomm.com"],
    LocalContact *localContactConferenceApp = [[LocalContact alloc] initWithFirstName:@"Conference" lastName:@"App" andPhoneNumbers:@[@"+1310"]]; //@"sip:+1311@cloud.restcomm.com"],
    LocalContact *localContactConferenceAdminApp = [[LocalContact alloc] initWithFirstName:@"Conference" lastName:@"Admin App" andPhoneNumbers:@[@"+1311"]]; //@"sip:+1310@cloud.restcomm.com"],
    
    return  @[localContactPlayApp, localContactSayApp, localContactGatherApp, localContactConferenceApp, localContactConferenceAdminApp];
    
}

+ (NSDictionary *)getDefaultChatHistory{
   return @{
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
      };
}

#pragma mark - Helpers

+ (NSArray *)getFilteredContactArray:(NSArray *)contactsArray{
    //return non deleted contacts
    NSPredicate *filterDeleted = [NSPredicate predicateWithFormat:@"deleted == NO"];
    return [contactsArray filteredArrayUsingPredicate:filterDeleted];
}

@end
