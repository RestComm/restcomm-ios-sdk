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


//keys
NSString *const kContactKey = @"contacts";
NSString *const kLastPeerKey = @"last-peer";
NSString *const kChatHistoryKey = @"chat-history";
NSString *const kSipIndentificationKey = @"sip-identification";
NSString *const kSipPasswordKey = @"sip-password";
NSString *const kSipRegistrarKey = @"sip-registrar";
NSString *const kTurnEnabledKey = @"turn-enabled";
NSString *const kTurnUrlKey = @"turn-url";
NSString *const kTurnUsernameKey = @"turn-username";
NSString *const kTurnPasswordKey = @"turn-password";
NSString *const kSignalingSecureKey = @"signaling-secure";
NSString *const kTurnCanidateTimeoutKey = @"turn-candidate-timeout";
NSString *const kIsFirstTimeKey = @"is-first-time";
NSString *const kPendingInterappKey = @"pending-interapp-uri";
NSString *const kSignalingCertificateKey = @"signaling-certificate-dir";

NSString *const kPushAccountKey = @"push-account";
NSString *const kPushPasswordKey = @"push-password";
NSString *const kPushDomainKey = @"push-domain";
NSString *const kPushTokenKey = @"push-token";



@implementation Utils

NSString* const RestCommClientSDKLatestGitHash = @"#GIT-HASH";
NSString* const kFriendlyName = @"Olympus";

+ (void) setupUserDefaults
{
    
    // DOC: very important. To add a NSDictionary or NSArray as part of NSUserDefaults the key must always be an NSString!
    NSDictionary *basicDefaults = @{
                                    kIsFirstTimeKey : @(YES),
                                    kPendingInterappKey : @"",  // has another app sent us a URL to call?
                                    kSipIndentificationKey : @"",  //@"sip:ios-sdk@cloud.restcomm.com",
                                    kSipPasswordKey : @"",
                                    kSipRegistrarKey : @"cloud.restcomm.com",
                                    kTurnEnabledKey : @(YES),
                                    kTurnUrlKey : @"https://es.xirsys.com/_turn", // @"https://service.xirsys.com/ice", // @"https://computeengineondemand.appspot.com/turn",
                                    kTurnUsernameKey : @"atsakiridis",  // @"iapprtc",
                                    kTurnPasswordKey : @"4e89a09e-bf6f-11e5-a15c-69ffdcc2b8a7",  // @"4080218913"
                                    kSignalingSecureKey : @(YES),  // by default signaling is secure
                                    kSignalingCertificateKey : @"",
                                    kPushAccountKey: @"",
                                    kPushPasswordKey: @"",
                                    kPushTokenKey: @"",
                                    kPushDomainKey: @"https://push.restcomm.com",
                                    //@"turn-candidate-timeout" : @"5",
                                    kContactKey : [NSKeyedArchiver archivedDataWithRootObject:[Utils getDefaultContacts]],
                                    kChatHistoryKey : [Utils getDefaultChatHistory], // a dictionary of chat histories (key is remote party full sip URI)
                                    };
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:basicDefaults];
}

#pragma mark - Contacts

+ (int)indexForContact:(NSString*)sipUri
{
    //index for contact is only for filtered array (non deleted contacts)
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
           NSArray *filterdArray = [Utils getNonDeletedFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                LocalContact *localContact = [filterdArray objectAtIndex:i];
                
                //Phone numbers
                if (localContact.phoneNumbers && localContact.phoneNumbers.count > 0 && [localContact.phoneNumbers containsObject:sipUri]){
                    return i;
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

+ (LocalContact*)getContactForSipUri:(NSString*)sipUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
   
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getNonDeletedFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                LocalContact *localContact = [filterdArray objectAtIndex:i];
                
                //Phone numbers
                if (localContact.phoneNumbers && localContact.phoneNumbers.count > 0 && [localContact.phoneNumbers containsObject:sipUri]){
                    return localContact;
                }
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

+ (int)contactCount
{
    NSData *contactsArrayData = [[NSUserDefaults standardUserDefaults] objectForKey:kContactKey];
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            //return non deleted contacts
            NSArray *filterdArray = [Utils getNonDeletedFilteredContactArray:contactsArray];
            return (int)[filterdArray count];
        }
    }
    return 0;
}

+ (void)addContact:(LocalContact *)contact
{
    NSUserDefaults *appDefaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray * mutable = nil;
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
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
            if (![contact.phoneNumbers isEqualToArray:savedContact.phoneNumbers]){
                //just copy numbers
                savedContact.phoneNumbers = contact.phoneNumbers;
                [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:@"contacts"];
            }
            break;
        }
    }
    
    if (!exists){
        [mutable addObject:contact];
    }
    // update user defaults
    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:kContactKey];
}

+ (void)removeContact:(LocalContact *)localContact
{
    //contact will have the flag deleted set to true
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray * mutable = nil;
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
    
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            mutable = [contactsArray mutableCopy];
            for (int i=0; i<mutable.count; i ++){
                LocalContact *fromNonFilteredContact = [mutable objectAtIndex:i];
                if ([fromNonFilteredContact isEqual:localContact]){
                    fromNonFilteredContact.deleted = YES;
                    // update user defaults
                    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:kContactKey];
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

+ (void)updateContactWithSipUri:(NSString*)sipUri forAlias:(NSString*)alias
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
    
    if (contactsArrayData != nil) {
        NSArray *contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        if (contactsArray != nil){
            NSArray *filterdArray = [Utils getNonDeletedFilteredContactArray:contactsArray];
            for (int i=0; i < filterdArray.count; i ++){
                NSMutableArray *mutable = [contactsArray mutableCopy];
                LocalContact *localContact = [mutable objectAtIndex:i];
                NSString *localAlias = [NSString stringWithFormat:@"%@ %@", localContact.firstName, localContact.lastName];
                if ([localAlias isEqualToString:alias]){
                    localContact.phoneNumbers = @[sipUri];
                    [appDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:mutable] forKey:@"contacts"];
                    return;
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

+ (void)saveLastPeer:(NSString *)sipUri{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipUri forKey:kLastPeerKey];
}

+ (NSString *)getLastPeer{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults objectForKey:kLastPeerKey];
}


#pragma mark - Messages

+ (NSArray*)messagesForSipUri:(NSString*)sipUri
{
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    if ([appDefaults dictionaryForKey:kChatHistoryKey] && [[appDefaults dictionaryForKey:kChatHistoryKey] objectForKey:sipUri]) {
        return [[appDefaults dictionaryForKey:kChatHistoryKey] objectForKey:sipUri];
    }
    return messages;
}

+ (void)addMessageForSipUri:(NSString*)sipUri text:(NSString*)text type:(NSString*)type
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray * aliasMessages = [[NSMutableArray alloc] init];
    if (![appDefaults dictionaryForKey:kChatHistoryKey]) {
        return;
    }
    
    NSMutableDictionary * messages = [[appDefaults dictionaryForKey:kChatHistoryKey] mutableCopy];
    if ([messages objectForKey:sipUri]) {
        aliasMessages = [[messages objectForKey:sipUri] mutableCopy];
    }
    
    [aliasMessages addObject:[NSDictionary dictionaryWithObjectsAndKeys:text, @"text", type, @"type", nil]];
    [messages setObject:aliasMessages forKey:sipUri];
    
    [appDefaults setObject:messages forKey:kChatHistoryKey];
}

#pragma mark - SIP

+ (NSString*)sipIdentification
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kSipIndentificationKey];
}

+ (NSString*)sipPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kSipPasswordKey];
}

+ (NSString*)sipRegistrar
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kSipRegistrarKey];
}

+ (BOOL)turnEnabled
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:kTurnEnabledKey] boolValue];
}

+ (BOOL)signalingSecure
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:kSignalingSecureKey] boolValue];
}

+ (NSString*)turnUrl
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kTurnUrlKey];
}

+ (NSString*)turnUsername
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kTurnUsernameKey];
}

+ (NSString*)turnPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kTurnPasswordKey];
}

+ (NSString*)turnCandidateTimeout
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kTurnCanidateTimeoutKey];
}

+ (BOOL)isFirstTime
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [[appDefaults stringForKey:kIsFirstTimeKey] boolValue];
}

+ (NSString*)pendingInterappUri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kPendingInterappKey];
}

+ (void)updateSipIdentification:(NSString*)sipIdentification
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipIdentification forKey:kSipIndentificationKey];
}

+ (void)updateSipPassword:(NSString*)sipPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipPassword forKey:kSipPasswordKey];
}

+ (void)updateSipRegistrar:(NSString*)sipRegistrar
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:sipRegistrar forKey:kSipRegistrarKey];
}

+ (void)updateTurnEnabled:(BOOL)turnEnabled
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:@(turnEnabled) forKey:kTurnEnabledKey];
}

+ (void)updateTurnUrl:(NSString*)turnUrl
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnUrl forKey:kTurnUrlKey];
}

+ (void)updateTurnUsername:(NSString*)turnUsername
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnUsername forKey:kTurnUsernameKey];
}

+ (void)updateTurnPassword:(NSString*)turnPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnPassword forKey:kTurnPasswordKey];
}

+ (void)updateTurnCandidateTimeout:(NSString*)turnCandidateTimeout
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:turnCandidateTimeout forKey:kTurnCanidateTimeoutKey];
}

+ (void)updateIsFirstTime:(BOOL)isFirstTime
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:[NSNumber numberWithBool:isFirstTime] forKey:kIsFirstTimeKey];
}

+ (void)updatePendingInterappUri:(NSString*)uri
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:uri forKey:kPendingInterappKey];
}

+ (void)updateSignalingSecure:(BOOL)signalingSecure
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:@(signalingSecure) forKey:kSignalingSecureKey];
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

+ (NSArray *)getSortedContacts{
    NSArray *contactsArray = [[NSArray alloc] init];
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSData *contactsArrayData = [appDefaults objectForKey:kContactKey];
    
    if (contactsArrayData != nil) {
        contactsArray = [NSKeyedUnarchiver unarchiveObjectWithData: contactsArrayData];
        contactsArray = [Utils getNonDeletedFilteredContactArray:contactsArray];
        if (contactsArray != nil){
  
            NSSortDescriptor *sortFirstName = [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES selector:@selector(caseInsensitiveCompare:)];
            NSSortDescriptor *sortLastName = [NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES selector:@selector(caseInsensitiveCompare:)];
            
            contactsArray = [contactsArray sortedArrayUsingDescriptors:@[sortFirstName, sortLastName]];
        }
    }
    return contactsArray;
}

#pragma mark - Push Notifications

+ (NSString *)pushAccount{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kPushAccountKey];
}

+ (NSString *)pushPassword{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kPushPasswordKey];
}

+ (NSString *)pushDomain{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kPushDomainKey];
}

+ (NSString *)pushToken{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    return [appDefaults stringForKey:kPushTokenKey];
}

+ (void)updatePushAccount:(NSString *)pushAccount
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:pushAccount forKey:kPushAccountKey];
}

+ (void)updatePushPassword:(NSString *)pushPassword
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:pushPassword forKey:kPushPasswordKey];
}

+ (void)updatePushDomain:(NSString *)pushDomain
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:pushDomain forKey:kPushDomainKey];
}

+ (void)updatePushToken:(NSString *)pushToken
{
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:pushToken forKey:kPushTokenKey];
}

#pragma mark - Default values

+ (NSArray *)getDefaultContacts{

    
    LocalContact *localContactPlayApp = [[LocalContact alloc] initWithFirstName:@"Play"
                                                                       lastName:@"App"
                                                                phoneNumbers:@[@"+1234"]
                                                           andIsPhoneBookNumber:NO]; //@"sip:+1234@cloud.restcomm.com"],
    
    LocalContact *localContactSayApp = [[LocalContact alloc] initWithFirstName:@"Say"
                                                                      lastName:@"App"
                                                               phoneNumbers:@[@"+1235"]
                                                          andIsPhoneBookNumber:NO]; //@"sip:+1235@cloud.restcomm.com"],
    
    LocalContact *localContactGatherApp = [[LocalContact alloc] initWithFirstName:@"Gather"
                                                                         lastName:@"App"
                                                                     phoneNumbers:@[@"+1236"]
                                                             andIsPhoneBookNumber:NO]; //@"sip:+1236@cloud.restcomm.com"],
    
    LocalContact *localContactConferenceApp = [[LocalContact alloc] initWithFirstName:@"Conference"
                                                                             lastName:@"App"
                                                                         phoneNumbers:@[@"+1310"]
                                                                 andIsPhoneBookNumber:NO]; //@"sip:+1311@cloud.restcomm.com"],
    
    LocalContact *localContactConferenceAdminApp = [[LocalContact alloc] initWithFirstName:@"Conference"
                                                                                  lastName:@"Admin App"
                                                                              phoneNumbers:@[@"+1311"]
                                                                      andIsPhoneBookNumber: NO]; //@"sip:+1310@cloud.restcomm.com"],
    
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

+ (NSArray *)getNonDeletedFilteredContactArray:(NSArray *)contactsArray{
    //return non deleted contacts
    NSPredicate *filterDeleted = [NSPredicate predicateWithFormat:@"deleted == NO"];
    return [contactsArray filteredArrayUsingPredicate:filterDeleted];
}


#pragma mark - View animations

+ (void)shakeView:(UIView *)view {
    
    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
    [shake setDuration:0.2];
    [shake setRepeatCount:2];
    [shake setAutoreverses:YES];
    [shake setFromValue:[NSValue valueWithCGPoint:
                         CGPointMake(view.center.x - 10,view.center.y)]];
    [shake setToValue:[NSValue valueWithCGPoint:
                       CGPointMake(view.center.x + 10, view.center.y)]];
    [view.layer addAnimation:shake forKey:@"position"];
}


@end
