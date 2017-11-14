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
#import "RCUtilities.h"
#import "Utils.h"

#import <Contacts/Contacts.h>
#import "LocalContact.h"
#import "AppDelegate.h"


@interface MainTableViewController () 

@property (nonatomic, strong) CNContactStore *contactsStore;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *contactsData;
@property (nonatomic, strong) NSMutableArray *displayedContacts;
@property (nonatomic, strong) NSMutableArray *filteredContactsData;
@property (nonatomic, strong) NSArray *searchResults;
@property (nonatomic, strong) UISearchController * searchController;
@end

@implementation MainTableViewController{
   AppDelegate *appDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    
    UIColor *grey = [UIColor colorWithRed:109.0/255.0 green:110.0/255.0 blue:112/255.0 alpha:255.0/255.0];
    //[[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(0, -60) forBarMetrics:UIBarMetricsDefault];
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
    
    self.contactsStore = [[CNContactStore alloc] init];

    //define spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    //get contacts first time
    [self checkContactsAccess];

    
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self reloadData];
    // check connectivity
    
    if (appDelegate.device){
        [self updateConnectivityState:appDelegate.device.state
              andConnectivityType:appDelegate.device.connectivityType
                         withText:@""];
    } else {
        [appDelegate registerRCDevice];
    }
    
    //notification handled from app delegate
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateStatusNotification:)
                                                 name:@"UpdateConnectivityStatus"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData:)
                                                 name:@"ReloadData"
                                               object:nil];
    
    
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Local notification

- (void)updateStatusNotification:(NSNotification *) notification{
    NSDictionary *userInfo = notification.userInfo;
    
    RCDeviceState state = (RCDeviceState)[[userInfo valueForKey:@"state"] intValue];
    RCDeviceConnectivityType status = (RCDeviceConnectivityType)[[userInfo valueForKey:@"status"] intValue];
    
    [self updateConnectivityState:state
              andConnectivityType:status
                         withText:[userInfo objectForKey:@"text"]];
    
}

- (void)reloadData:(NSNotification *) notification{
    [self reloadData];
}

- (void)appWillEnterForeground:(NSNotification *)notification{
    //get contacts everytime app is back from background, maybe some contacts are updated/added
    [self checkContactsAccess];
}

#pragma mark - Update connectivity state notification

- (void)updateConnectivityState:(RCDeviceState)state andConnectivityType:(RCDeviceConnectivityType)status withText:(NSString *)text{
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
        (![text isEqualToString:@""] && status != appDelegate.previousDeviceState)) {
        
        // Let's use toast notifications that are much more suitable now that we implemented them
        [[ToastController sharedInstance] showToastWithText:text withDuration:2.0];
    }
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
        settingsTableViewController.device = appDelegate.device;
    }
    
    if ([segue.identifier isEqualToString:@"invoke-create-contact"]) {
        ContactUpdateTableViewController *contactUpdateViewController = [segue destinationViewController];
        contactUpdateViewController.delegate = appDelegate;
    }
    
    if ([segue.identifier isEqualToString:@"invoke-messages"]){
        NSString *alias = [NSString stringWithFormat:@"%@ %@", contact.firstName, contact.lastName];
        if (contact.phoneNumbers.count > 0){
            NSString *username = [contact.phoneNumbers objectAtIndex:0];
            
            MessageTableViewController *messageViewController = [segue destinationViewController];
            messageViewController.device = appDelegate.device;
            messageViewController.delegate = appDelegate;
            
            messageViewController.parameters = [[NSMutableDictionary alloc] init];
            
            [messageViewController.parameters setObject:alias forKey:@"alias"];
            [messageViewController.parameters setObject:username forKey:RCUsername];
        }
    }
  
    if ([segue.identifier isEqualToString:@"invoke-details"]) {
        ContactDetailsTableViewController *contactDetailsTableViewController = [segue destinationViewController];
        contactDetailsTableViewController.device = appDelegate.device;
        contactDetailsTableViewController.delegate = appDelegate;
        contactDetailsTableViewController.localContact = contact;
    }
}

#pragma mark - Invoke methods

- (void)invokeSettings
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    SettingsTableViewController *settingsViewController = [storyboard instantiateViewControllerWithIdentifier:@"settings-view-controller"];
    settingsViewController.device = appDelegate.device;
    
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
