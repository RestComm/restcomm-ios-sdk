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

#import "AppDelegate.h"
#import "Utils.h"
#import "MainNavigationController.h"
#import "TestFairy/TestFairy.h"
#import "RCCallKitProvider.h"

@interface AppDelegate()<RCCallKitProviderDelegate>
@property (nonatomic, strong) PKPushRegistry * voipRegistry;
@property (nonatomic, strong) RCCallKitProvider *callKitProvider;

@end

@implementation AppDelegate

#pragma mark - AppDelegate lifecycle methods
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"application:didFinishLaunchingWithOptions");
    // register the preference defaults early with default values
    [Utils setupUserDefaults];

    // Override point for customization after application launch.
    //[TestFairy begin:@"#TESTFAIRY_APP_TOKEN"];
    
    //register for the push notification
    [self registerForPush];
    
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];
    [center removeAllPendingNotificationRequests];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:
                                                                         UIUserNotificationTypeAlert|
                                                                         UIUserNotificationTypeBadge|
                                                                         UIUserNotificationTypeSound categories:nil]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(register:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unregister:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    self.callKitProvider = [[RCCallKitProvider alloc] initWithDelegate:self];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    application.applicationIconBadgeNumber = 0;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions
{
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    [Utils updatePendingInterappUri:[Utils convertInterappUri2RestcommUri:url]];
    return YES;
}

#pragma mark - RCDevice methods

- (RCDevice *)registerRCDevice{
    //if sip indetification is not set, we should not register
    if ([[Utils sipIdentification] length] > 0 && !self.device){
        NSString *cafilePath = [[NSBundle mainBundle] pathForResource:@"cafile" ofType:@"pem"];
        //we should have those in settings in the future....
        /******************************/
        /* Xirsys v2 */
        /******************************/
        //    self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[Utils sipIdentification], @"aor",
        //                       [Utils sipPassword], @"password",
        //                       @([Utils turnEnabled]), @"turn-enabled",
        //                       [Utils turnUrl], @"turn-url",
        //                       @"cloud.restcomm.com", @"ice-domain",
        //                       [Utils turnUsername], @"turn-username",
        //                       [Utils turnPassword], @"turn-password",
        //                       @([Utils signalingSecure]), @"signaling-secure",
        //                       [cafilePath stringByDeletingLastPathComponent], @"signaling-certificate-dir",
        //                       [NSNumber numberWithInt:(int)kXirsysV2] , @"ice-config-type",
        //                       nil];
        /******************************/
        /* Xirsys v3 */
        /******************************/
        self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[Utils sipIdentification], @"aor",
                           [Utils sipPassword], @"password",
                           @([Utils turnEnabled]), @"turn-enabled",
                           [Utils turnUrl], @"turn-url",
                           [Utils turnUsername], @"turn-username",
                           [Utils turnPassword], @"turn-password",
                           @"cloud.restcomm.com", @"ice-domain",
                           @([Utils signalingSecure]), @"signaling-secure",
                           [cafilePath stringByDeletingLastPathComponent], @"signaling-certificate-dir",
                           [NSNumber numberWithInt:(int)kXirsysV3] , @"ice-config-type",
                           nil];
        /******************************/
        /* Xirsys custom */
        /******************************/
        //    NSDictionary *dictionaryServer = [[NSDictionary alloc] initWithObjectsAndKeys:
        //     @"46560f8e-94a7-11e7-bc4c-SOME_DATA", @"username",
        //     @"turn:Server:80?transport=udp", @"url",
        //     @"4656101a-94a7-11e7-97SOME_DATA", @"credential",
        //     nil];
        //
        //    NSDictionary *dictionaryServer2 = [[NSDictionary alloc] initWithObjectsAndKeys:
        //                                       @"stun:Server",@"url", nil];
        //
        //    self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[Utils sipIdentification], @"aor",
        //                    [Utils sipPassword], @"password",
        //                      @([Utils turnEnabled]), @"turn-enabled",
        //                      @([Utils signalingSecure]), @"signaling-secure",
        //                      [cafilePath stringByDeletingLastPathComponent], @"signaling-certificate-dir",
        //                      [NSNumber numberWithInt:(int)kCustom] , @"ice-config-type",
        //                      @[dictionaryServer, dictionaryServer2] , @"ice-servers",
        //                      nil];
        /******************************/
        
        [self.parameters setObject:[NSString stringWithFormat:@"%@", [Utils sipRegistrar]] forKey:@"registrar"];
        
        // initialize RestComm Client by setting up an RCDevice
        self.device = [[RCDevice alloc] initWithParams:self.parameters delegate:self];
        [self updateConnectivityState:self.device.state andConnectivityType:self.device.connectivityType withText:@""];
    }
    return self.device;
    
}

#pragma mark - UI events

- (void)register:(NSNotification *)notification
{
    if (self.device) {
        NSLog(@"Ognjen --- listen register AppDelegate");
        [self.device listen];
    }
}

- (void)unregister:(NSNotification *)notification
{
    [self.device unlisten];
    self.device  = nil;
}


#pragma mark - Delegate methods for RCDeviceDelegate

- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    NSLog(@"Ognjen ------   didStopListeningForIncomingConnections: error: %p", error);
    // if error is nil then this is not an error condition, but an event that we have stopped listening after user request, like RCDevice.unlinsten
    if (error) {
        [self updateConnectivityState:device.state
                   andConnectivityType:device.connectivityType
                              withText:error.localizedDescription];
    }
}

- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
     NSLog(@"Ognjen ------   deviceDidStartListeningForIncomingConnections");
    [self updateConnectivityState:device.state
               andConnectivityType:device.connectivityType
                          withText:nil];
    
    NSString * pendingInterapUri = [Utils pendingInterappUri];
    if (pendingInterapUri && ![pendingInterapUri isEqualToString:@""]) {
        // we have a request from another iOS to make a call to the passed URI
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
        CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
        
        callViewController.delegate = self;
        callViewController.device = self.device;
        callViewController.parameters = [[NSMutableDictionary alloc] init];
        [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
        
        // search through the contacts if the given URI is known and if so use its alias, if not just use the URI
        LocalContact *localContact = [Utils getContactForSipUri:pendingInterapUri];
        NSString * alias;
        if (!localContact) {
            alias = pendingInterapUri;
        } else {
            alias = [NSString stringWithFormat:@"%@ %@", localContact.firstName, localContact.lastName];
        }
        [callViewController.parameters setObject:alias forKey:@"alias"];
        [callViewController.parameters setObject:pendingInterapUri forKey:@"username"];
        [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:@"video-enabled"];
        
        [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:callViewController animated:YES completion:nil];
        
        // clear it so that it doesn't pop again
        [Utils updatePendingInterappUri:@""];
    }
}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message withParams:(NSDictionary *)params
{
    NSLog(@"Ognjen ------   didReceiveIncomingMessage:  %@", message);
    if ([[[[UIApplication sharedApplication] keyWindow] rootViewController] isKindOfClass:UINavigationController.class] ){
        UINavigationController *navigationController = (UINavigationController *)[[[UIApplication sharedApplication] keyWindow] rootViewController];
        // Open message view if not already opened
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
        if (![navigationController.visibleViewController isKindOfClass:[MessageTableViewController class]]) {
            MessageTableViewController *messageViewController = [storyboard instantiateViewControllerWithIdentifier:@"message-controller"];
            //messageViewController.delegate = self;
            messageViewController.device = self.device;
            messageViewController.delegate = self;
            messageViewController.parameters = [[NSMutableDictionary alloc] init];
            [messageViewController.parameters setObject:message forKey:@"message-text"];
            [messageViewController.parameters setObject:@"receive-message" forKey:@"invoke-view-type"];
            [messageViewController.parameters setObject:[params objectForKey:@"from"] forKey:@"username"];
            [messageViewController.parameters setObject:[RCUtilities usernameFromUri:[params objectForKey:@"from"]] forKey:@"alias"];
            
            messageViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [navigationController pushViewController:messageViewController animated:YES];
        }
        else {
            // message view already opened, just append
            MessageTableViewController * messageViewController = (MessageTableViewController*)navigationController.visibleViewController;
            [messageViewController appendToDialog:message sender:[params objectForKey:@"from"]];
        }
    }
    
}

// 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
    NSLog(@"Ognjen ------   didReceiveIncomingConnection");
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive){
        //Answer with callkit
        self.callKitProvider.connection = connection;
        [self.callKitProvider answerWithCallKit];
   } else {
       [self openCallView:connection isFromCallKit:NO];
   }
}


-(void)openCallView:(RCConnection *)connection isFromCallKit:(BOOL)fromCallKit{
    // Open call view
    NSLog(@"Ognjen ------- openCallView");
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.pendingIncomingConnection = connection;
    callViewController.pendingIncomingConnection.delegate = callViewController;

    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"receive-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:[connection.parameters objectForKey:@"from"]  forKey:@"username"];
    // try to 'resolve' the from to the contact name if we do have a contact for that
    LocalContact *localContact = [Utils getContactForSipUri:[connection.parameters objectForKey:@"from"]];
    NSString * alias;
    if (!localContact) {
        alias = [connection.parameters objectForKey:@"from"];
    } else {
        alias = [NSString stringWithFormat:@"%@ %@", localContact.firstName, localContact.lastName];
    }
    
    [callViewController.parameters setObject:alias forKey:@"alias"];
    
    // TODO: change this once I implement the incoming call caller id
    //[callViewController.parameters setObject:@"CHANGEME" forKey:@"username"];
    
    callViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    if (fromCallKit){
        callViewController.rcCallKitProvider = self.callKitProvider;
    }
    [[[[UIApplication sharedApplication] keyWindow] rootViewController]  presentViewController:callViewController animated:YES completion:nil];
    
}

- (void)updateConnectivityState:(RCDeviceState)state andConnectivityType:(RCDeviceConnectivityType)status withText:(NSString *)text
{
    //send notification to view controllers
    NSMutableDictionary *propertyDictionary = [NSMutableDictionary dictionaryWithCapacity:6];
    [propertyDictionary setObject:[NSNumber numberWithInt:state] forKey:@"state"];
    [propertyDictionary setObject:[NSNumber numberWithInt:status] forKey:@"status"];
    if (text){
        [propertyDictionary setObject:text forKey:@"text"];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UpdateConnectivityStatus" object:self userInfo:propertyDictionary];
    self.previousDeviceState = state;
}

#pragma mark - ContactUpdateDelegate method

- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
     [[NSNotificationCenter defaultCenter] postNotificationName:@"ReloadData" object:self];
}

#pragma mark - ContactDetailsDelegate method

- (void)contactDetailsViewController:(ContactDetailsTableViewController*)contactDetailsViewController
           didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ReloadData" object:self];
}

#pragma mark - MessageDelegate method

- (void)messageViewController:(MessageTableViewController*)messageViewController
       didAddContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ReloadData" object:self];
}

#pragma mark - SipSettingsDelegate method

// User requested new registration in 'Settings'
- (void)sipSettingsTableViewController:(SipSettingsTableViewController*)sipSettingsTableViewController didUpdateRegistrationWithString:(NSString *)registrar
{
    [self updateConnectivityState:RCDeviceStateOffline
              andConnectivityType:RCDeviceConnectivityTypeNone
                         withText:@""];
}

#pragma mark - Push Notification

- (void)registerForPush{
    [[UIApplication sharedApplication] registerForRemoteNotifications]; // required to get the app to do anything at all about push notifications
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue: mainQueue];
    self.voipRegistry.delegate = self;
    self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

// Handle updated push credentials
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials: (PKPushCredentials *)credentials forType:(NSString *)type {
    if([credentials.token length] == 0) {
        NSLog(@"voip token NULL");
        return;
    }
    NSString * deviceTokenString = [[[[credentials.token description]
                                      stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                     stringByReplacingOccurrencesOfString: @">" withString: @""]
                                    stringByReplacingOccurrencesOfString: @" " withString: @""];

    //save token to user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:deviceTokenString forKey:@"deviceToken"];
}


// Handle incoming pushes
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {
    NSLog(@"Ognjen ---pushReceived");
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateBackground || state == UIApplicationStateInactive)
    {
        if (!self.device){
            //no need to wait, register and listen
            self.device = [self registerRCDevice];
            [self.device listen];
        }
    }
}

#pragma mark Starting call
- (void)openMessagesScreen{
//    NSString *username = [contact.phoneNumbers objectAtIndex:0];
//    
//    MessageTableViewController *messageViewController = [segue destinationViewController];
//    messageViewController.device = appDelegate.device;
//    messageViewController.delegate = appDelegate;
//    
//    messageViewController.parameters = [[NSMutableDictionary alloc] init];
//    
//    [messageViewController.parameters setObject:alias forKey:@"alias"];
//    [messageViewController.parameters setObject:username forKey:@"username"];
}


#pragma mark RCCallKitProviderDelegate method
- (void)newIncomingCallAnswered:(RCConnection *)connection{
    if ([[[UIApplication sharedApplication] keyWindow] rootViewController]){
        [[[[UIApplication sharedApplication] keyWindow] rootViewController] dismissViewControllerAnimated:NO completion:nil];
    }
    [self openCallView:connection isFromCallKit:YES];
}

- (void)callEnded{
    
    if (self.device){
        [self.device unlisten];
        self.device = nil;
        self.device.delegate = nil;
    }
}
@end
