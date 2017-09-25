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

#import "MainNavigationController.h"
#import "SettingsTableViewController.h"
#import "CallViewController.h"
#import "MessageTableViewController.h"
#import "MainTableViewController.h"
#import "ContactDetailsTableViewController.h"
#import "ContactUpdateTableViewController.h"

#import "ToastController.h"
#import "RestCommClient.h"
#import "RCUtilities.h"
#import "Utils.h"

#import <Contacts/Contacts.h>
#import "LocalContact.h"


@interface MainTableViewController () 
@property RCDeviceState previousDeviceState;

@property (nonatomic, strong) CNContactStore *contactsStore;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *contactsData;
@property (nonatomic, strong) NSMutableArray *displayedContacts;
@property (nonatomic, strong) NSMutableArray *filteredContactsData;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchController * searchController;

@end

@implementation MainTableViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIColor *grey = [UIColor colorWithRed:109.0/255.0 green:110.0/255.0 blue:112/255.0 alpha:255.0/255.0];
    [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(0, -60)
                                                         forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.tintColor = grey;
    
    //set button bar
    UIBarButtonItem * editButton = [self editButtonItem];
    [editButton setTintColor:grey];
    
    UIBarButtonItem * addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                target:self
                                                                                action:@selector(invokeCreateContact)];
    [addButton setTintColor:grey];
    
    
    UIBarButtonItem *barBugButton = [[UIBarButtonItem alloc] initWithCustomView:[self getBugReportButton]];
    
    self.navigationItem.rightBarButtonItems = [[NSArray alloc] initWithObjects:editButton, addButton, barBugButton, nil];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // remove empty cells from tableview
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.isRegistered = NO;
    self.isInitialized = NO;
    
    self.contactsData = [[NSArray alloc] init];
    self.displayedContacts = [self.contactsData mutableCopy];
    
    //filtered contacts
    self.filteredContactsData = [[NSMutableArray alloc] init];
    
    //TODO: capabilityTokens aren't handled yet
    //NSString* capabilityToken = @"";
    
    //create a Search controller
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.delegate = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.definesPresentationContext = YES;

    [self.searchController.searchBar sizeToFit];
    
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    
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
    
    if (self.device.state == RCDeviceStateOffline) {
        [self updateConnectivityStatus:self.device.state
                   andConnectivityType:self.device.connectivityType
                              withText:@""];
    }
    else {
        [self updateConnectivityStatus:self.device.state
                   andConnectivityType:self.device.connectivityType
                              withText:@""];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(register:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unregister:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    self.contactsStore = [[CNContactStore alloc] init];

    //define spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    //get contacts first time
    [self checkContactsAccess];
    
#warning this will be moved into app delegate; for now we are handling it here
    //if there is a token we got it before openning this viewcontroller (this is only
    //for the first time when user takes up time to login
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *deviceToken = [appDefaults objectForKey:@"deviceToken"];
    
    [self registerForPush:deviceToken];
    
    if (!deviceToken){
        //otherwise subscribe to notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(tokenReceivedNotification:)
                                                     name:@"TokenReceivedNotification"
                                                   object:nil];
        
    }
    
}

- (void) tokenReceivedNotification:(NSNotification *) notification
{
    if ([[notification name] isEqualToString:@"TokenReceivedNotification"]){
        NSDictionary *userInfo = notification.userInfo;
        NSString *deviceToken = [userInfo objectForKey:@"deviceTokenKey"];
        [self registerForPush:deviceToken];
    }
}

- (void) registerForPush:(NSString *)token{
   if (token){
        NSString *pushCertificatesPathPublic = [[NSBundle mainBundle] pathForResource:@"certificate_key_push" ofType:@"pem"];
        NSString *pushCertificatesPathPrivate = [[NSBundle mainBundle] pathForResource:@"rsa_private_key_push" ofType:@"pem"];
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                    @"Olympus", @"friendly-name",
                                    @"USER_NAME", @"username",
                                    @"PASSWORD", @"password",
                                    @"EMAIL", @"rescomm-account-email",
                                    token, @"token",
                                    pushCertificatesPathPublic, @"push-certificate-public-path",
                                    pushCertificatesPathPrivate, @"push-certificate-private-path",
                                    [NSNumber numberWithBool:YES], @"Sandbox", nil];
                                    //for the production version Sandbox should be NO
        
        [self.device registerPushToken:dic];
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"deviceToken"];
    } else {
        NSLog(@"deviceToken is missing!");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)appWillEnterForeground:(NSNotification *)notification{
    //get contacts everytime app is back from background, maybe some contacts are updated/added
    [self checkContactsAccess];
}


#pragma mark - UI events

- (void)register:(NSNotification *)notification
{
      if (self.device && self.isInitialized) {
        [self register];
    }
}

- (void)register
{
    [self.device listen];
    self.isRegistered = YES;
}

- (void)unregister:(NSNotification *)notification
{
    [self.device unlisten];
    self.isRegistered = NO;
}

#pragma mark - Delegate methods for RCDeviceDelegate

- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    //NSLog(@"------ didStopListeningForIncomingConnections: error: %p", error);
    // if error is nil then this is not an error condition, but an event that we have stopped listening after user request, like RCDevice.unlinsten
    if (error) {
        [self updateConnectivityStatus:device.state
                   andConnectivityType:device.connectivityType
                              withText:error.localizedDescription];
    }
}

- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    self.isInitialized = YES;
    self.isRegistered = YES;
    
    [self updateConnectivityStatus:device.state
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
        
        [self presentViewController:callViewController animated:YES completion:nil];
        
        // clear it so that it doesn't pop again
        [Utils updatePendingInterappUri:@""];
    }
}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message withParams:(NSDictionary *)params
{
    // Open message view if not already opened
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    if (![self.navigationController.visibleViewController isKindOfClass:[MessageTableViewController class]]) {
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
        [self.navigationController pushViewController:messageViewController animated:YES];
    }
    else {
        // message view already opened, just append
        MessageTableViewController * messageViewController = (MessageTableViewController*)self.navigationController.visibleViewController;
        [messageViewController appendToDialog:message sender:[params objectForKey:@"from"]];
    }
}

// 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
    // Open call view
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.pendingIncomingConnection = connection;
    callViewController.pendingIncomingConnection.delegate = callViewController;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"receive-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:[connection.parameters objectForKey:@"from"] forKey:@"username"];
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
    [self presentViewController:callViewController
                       animated:YES
                     completion:nil];
}

- (void)updateConnectivityStatus:(RCDeviceState)state andConnectivityType:(RCDeviceConnectivityType)status withText:(NSString *)text
{
    //NSLog(@"------ updateConnectivityStatus: status: %d, text: %@", status, text);
    NSString * imageName = @"inapp-icon-28x28.png";
    
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc]
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [activityView startAnimating];
    UIBarButtonItem *barIndicator = [[UIBarButtonItem alloc] initWithCustomView:activityView];
    
    NSMutableArray * itemsArray = [[NSMutableArray alloc] init];
    
    NSString * defaultText = nil;
    if (state == RCDeviceStateOffline) {
        defaultText = @"Lost connectivity";
        imageName = @"inapp-grey-icon-28x28.png";
        [itemsArray addObject:barIndicator];
    }
    if (state != RCDeviceStateOffline) {
        if (status == RCDeviceConnectivityTypeWifi) {
            defaultText = @"Reestablished connectivity (Wifi)";
        }
        if (status == RCDeviceConnectivityTypeCellularData) {
            defaultText = @"Reestablished connectivity (Cellular)";
        }
    }
    
    if (!text) {
        text = defaultText;
    }
    
    // Important: use imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal to avoid the default blue tint!
    UIBarButtonItem * restcommIconButton = [[UIBarButtonItem alloc] initWithImage:[[UIImage imageNamed:imageName]
                                                                                   imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(invokeSettings)];
    
    [itemsArray insertObject:restcommIconButton atIndex:0];
    
    self.navigationItem.leftBarButtonItems = itemsArray;
    
    if (![text isEqualToString:@""] ||
        (![text isEqualToString:@""] && status != self.previousDeviceState)) {
        
        // Let's use toast notifications that are much more suitable now that we implemented them
        [[ToastController sharedInstance] showToastWithText:text withDuration:2.0];
    }
    self.previousDeviceState = state;
}
#pragma mark - ContactUpdateDelegate method

- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [self reloadData];
}

#pragma mark - ContactDetailsDelegate method

- (void)contactDetailsViewController:(ContactDetailsTableViewController*)contactDetailsViewController
           didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [self reloadData];
}

#pragma mark - MessageDelegate method

- (void)messageViewController:(MessageTableViewController*)messageViewController
       didAddContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [self reloadData];
}

#pragma mark - SipSettingsDelegate method
// User requested new registration in 'Settings'
- (void)sipSettingsTableViewController:(SipSettingsTableViewController*)sipSettingsTableViewController didUpdateRegistrationWithString:(NSString *)registrar
{
    [self updateConnectivityStatus:RCDeviceStateOffline
               andConnectivityType:RCDeviceConnectivityTypeNone
                          withText:@""];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.displayedContacts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contact-reuse-identifier" forIndexPath:indexPath];
    
    // Configure the cell...
    LocalContact * contact = self.displayedContacts[(int)indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", contact.firstName, contact.lastName];
    cell.detailTextLabel.text = @"";
    
    //if there is more than 1 phone number, we are showing custom accessoryView
    if (contact.phoneNumbers && [contact.phoneNumbers count] > 0){
        cell.detailTextLabel.text = [contact.phoneNumbers objectAtIndex:0];
    }
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];

    [button addTarget:self action:@selector(checkButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
    cell.backgroundColor = [UIColor clearColor];
    cell.accessoryView = button;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self performSegueWithIdentifier:@"invoke-messages" sender:indexPath];
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [Utils removeContact:self.displayedContacts[indexPath.row]];
        //dismiss searchbar
        [self.searchController dismissViewControllerAnimated:YES completion:nil];
        self.searchController.searchBar.text = @"";
        [self reloadData];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Adding is handled in the separate screen
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }
}

#pragma mark - Search delegate methods
// When the user types in the search bar, this method gets called.
- (void)updateSearchResultsForSearchController:(UISearchController *)aSearchController {
    NSLog(@"updateSearchResultsForSearchController");
    
    NSString *searchString = aSearchController.searchBar.text;
    NSLog(@"searchString=%@", searchString);
    
    // Check if search is cancelled or deleted the search so
    // we can display the full list instead.
    if (![searchString isEqualToString:@""]) {
        [self.filteredContactsData removeAllObjects];
        for (LocalContact *localContact in self.contactsData) {
            NSString *firstNameLastName = [NSString stringWithFormat:@"%@ %@", localContact.firstName, localContact.lastName];
            if ([firstNameLastName isEqualToString:@""] || [firstNameLastName localizedCaseInsensitiveContainsString:searchString] == YES) {
                [self.filteredContactsData addObject:localContact];
            }
        }
        self.displayedContacts = self.filteredContactsData;
    }
    else {
        self.displayedContacts = [self.contactsData mutableCopy];
    }
    [self.tableView reloadData];
}

#pragma mark - AccessoryView button tap
- (void)checkButtonTapped:(id)sender event:(id)event
{
    NSSet *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self.tableView];
    
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint: currentTouchPosition];
    if (indexPath != nil)
    {
        [self performSegueWithIdentifier:@"invoke-details" sender:indexPath];
    }
}


#pragma mark - PrepareForSegue

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    LocalContact * contact;
    if ([segue.identifier isEqualToString:@"invoke-details"] || [segue.identifier isEqualToString:@"invoke-messages"]){
        NSIndexPath * indexPath = sender;
        contact = self.displayedContacts[(int)indexPath.row];
    }
    
    if ([segue.identifier isEqualToString:@"invoke-settings"]) {
        SettingsTableViewController * settingsTableViewController = [segue destinationViewController];
        settingsTableViewController.device = self.device;
    }
    
    if ([segue.identifier isEqualToString:@"invoke-create-contact"]) {
        ContactUpdateTableViewController *contactUpdateViewController = [segue destinationViewController];
        contactUpdateViewController.delegate = self;
    }
    
    if ([segue.identifier isEqualToString:@"invoke-messages"]){
        NSString *alias = [NSString stringWithFormat:@"%@ %@", contact.firstName, contact.lastName];
        if (contact.phoneNumbers.count > 0){
            NSString *username = [contact.phoneNumbers objectAtIndex:0];
            
            MessageTableViewController *messageViewController = [segue destinationViewController];
            messageViewController.device = self.device;
            messageViewController.delegate = self;
            
            messageViewController.parameters = [[NSMutableDictionary alloc] init];
            
            [messageViewController.parameters setObject:alias forKey:@"alias"];
            [messageViewController.parameters setObject:username forKey:@"username"];
        }
    }
  
    if ([segue.identifier isEqualToString:@"invoke-details"]) {
        ContactDetailsTableViewController *contactDetailsTableViewController = [segue destinationViewController];
        contactDetailsTableViewController.device = self.device;
        contactDetailsTableViewController.delegate = self;
        contactDetailsTableViewController.localContact = contact;
    }
}

#pragma mark - Invoke methods

- (void)invokeSettings
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    SettingsTableViewController *settingsViewController = [storyboard instantiateViewControllerWithIdentifier:@"settings-view-controller"];
    settingsViewController.device = self.device;
    
    [self.navigationController pushViewController:settingsViewController animated:YES];
    
}

- (void)invokeCreateContact
{
   [self performSegueWithIdentifier:@"invoke-create-contact" sender:nil];
}


- (void)invokeBugReport
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    // important: we are retrieving the navigation controller that hosts the contact update table view controller (due to the issue we had on the buttons showing wrong)
    UINavigationController *bugReportNavigationController = [storyboard instantiateViewControllerWithIdentifier:@"bug-report-nav-controller"];
    [self presentViewController:bugReportNavigationController animated:YES completion:nil];
}


#pragma mark - Rotation/Orientation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

#pragma mark - Contacts access request

-(void)checkContactsAccess{
    [self showSpinner];
    [self requestContactsAccessWithHandler:^(BOOL granted) {
        if (granted) {
                CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:
                                                  @[CNContactFamilyNameKey, CNContactGivenNameKey,
                                                    CNContactNamePrefixKey, CNContactMiddleNameKey, CNContactPhoneNumbersKey]];
                
                [self.contactsStore enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
                    
                    NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];
                    LocalContact *localContact = [[LocalContact alloc] init];
                    localContact.firstName = contact.givenName;
                    localContact.lastName = contact.familyName;
                    localContact.phoneBookNumber = YES;
                  
                    if (contact.phoneNumbers.count > 0 &&
                        ((localContact.firstName && localContact.firstName.length > 0) ||
                        (localContact.lastName && localContact.lastName.length > 0))) {
                        for (int i=0; i<contact.phoneNumbers.count; i++){
                            //add numbers to array
                            CNPhoneNumber *phoneNumber = (CNPhoneNumber *)contact.phoneNumbers[i].value;
                            [phoneNumbers addObject:[phoneNumber valueForKey:@"digits"]];
                        }
                        localContact.phoneNumbers = [NSArray arrayWithArray:phoneNumbers];
                        [Utils addContact:localContact];
                    }
                    
                }];
                
                dispatch_async( dispatch_get_main_queue(), ^{
                    [self hideSpinner];
                    [self reloadData];
                });
        } else {
            dispatch_async( dispatch_get_main_queue(), ^{
                [self hideSpinner];
            });
        }
    }];
}

-(void)requestContactsAccessWithHandler:(void (^)(BOOL granted))handler{
    switch ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts]) {
        case CNAuthorizationStatusAuthorized:
            handler(YES);
            break;
        case CNAuthorizationStatusDenied:
        case CNAuthorizationStatusNotDetermined:{
            [self.contactsStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                handler(granted);
            }];
            break;
        }
        case CNAuthorizationStatusRestricted:
            handler(NO);
            break;
    }
};

#pragma mark - Spinner

-(void) showSpinner{
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.view bringSubviewToFront:self.spinner];
    
    [self.spinner startAnimating];
}

-(void) hideSpinner{
    [self.spinner removeFromSuperview];
}

#pragma mark - Loader 

- (void)reloadData{
    self.contactsData = [Utils getSortedContacts];
    self.displayedContacts = [self.contactsData mutableCopy];
    [self.tableView reloadData];
}

#pragma mark - Helper

- (UIButton *)getBugReportButton{
    UIButton *bugButton =  [UIButton buttonWithType:UIButtonTypeCustom];
    [bugButton setImage:[UIImage imageNamed:@"bug-grey-icon-25x25.png"] forState:UIControlStateNormal];
    [bugButton addTarget:self action:@selector(invokeBugReport)forControlEvents:UIControlEventTouchUpInside];
    [bugButton setFrame:CGRectMake(0, 0, 25, 25)];
    return bugButton;
}

@end
