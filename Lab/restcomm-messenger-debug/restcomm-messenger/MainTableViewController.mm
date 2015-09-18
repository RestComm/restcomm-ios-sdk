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

//#include <unistd.h>

#import "ViewController.h"
#import "MainNavigationController.h"
#import "SettingsTableViewController.h"
#import "CallViewController.h"
#import "MessageViewController.h"
#import "MainTableViewController.h"
#import "ContactDetailsTableViewController.h"
#import "ContactUpdateTableViewController.h"

#import "RestCommClient.h"
#import "Utils.h"

@interface MainTableViewController ()

@end

@implementation MainTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // add edit button manually, to get the actions (from storyboard default actions for edit don't work)
    self.navigationItem.leftBarButtonItem = [self editButtonItem];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.isRegistered = NO;
    self.isInitialized = NO;
    
    // TODO: capabilityTokens aren't handled yet
    //NSString* capabilityToken = @"";
    
    self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[Utils sipIdentification], @"aor",
                       [Utils sipPassword], @"password",
                       nil];
    
    [self.parameters setObject:[NSString stringWithFormat:@"sip:%@", [Utils sipRegistrar]] forKey:@"registrar"];
    
    // initialize RestComm Client by setting up an RCDevice
    self.device = [[RCDevice alloc] initWithParams:self.parameters delegate:self];
    
    /*
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    [self.view addGestureRecognizer:tapGesture];
     */
    
/*
#ifdef DEBUG
    // set some defaults when in debug to avoid typing
    //NSArray * contact = [Utils contactForIndex:0];
    //self.sipUriText.text = [contact objectAtIndex:1];
    //self.sipUriText.text = @"sip:antonis@23.23.228.238:5080";
    //self.sipUriText.text = @"sip:alice@192.168.2.32:5080";
#else
    self.sipUriText.text = @"sip:1235@23.23.228.238:5080";
#endif
*/
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(register:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unregister:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)hideKeyBoard
{
    // resign both to be sure
    //[self.sipMessageText resignFirstResponder];
    //[self.sipUriText resignFirstResponder];
}

// ---------- UI events
- (void)register:(NSNotification *)notification
{
    if (self.device && self.isInitialized && !self.isRegistered) {
        if (self.device.state == RCDeviceStateOffline) {
            [self.device listen];
        }
        [self register];
    }
}

- (void)register
{
    // update our parms
    [self.device startSofia];
    //[self.device updateParams:self.parameters];
    self.isRegistered = YES;
}

- (void)unregister:(NSNotification *)notification
{
    [self.device stopSofia];
    //[self.device unlisten];
    self.isRegistered = NO;
}

// ---------- Delegate methods for RC Device
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    
}

// optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    
}

- (void)deviceDidInitializeSignaling:(RCDevice *)device
{
    //[self register];
    self.isInitialized = YES;
    self.isRegistered = YES;
}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message withParams:(NSDictionary *)params
{
    // Open message view if not already opened
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    if (![self.navigationController.visibleViewController isKindOfClass:[MessageViewController class]]) {
        MessageViewController *messageViewController = [storyboard instantiateViewControllerWithIdentifier:@"message-controller"];
        //messageViewController.delegate = self;
        messageViewController.device = self.device;
        messageViewController.parameters = [[NSMutableDictionary alloc] init];
        [messageViewController.parameters setObject:message forKey:@"message-text"];
        [messageViewController.parameters setObject:@"receive-message" forKey:@"invoke-view-type"];
        [messageViewController.parameters setObject:[params objectForKey:@"from"] forKey:@"username"];
        
        messageViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [self.navigationController pushViewController:messageViewController animated:YES];
    }
    else {
        // message view already opened, just append
        MessageViewController * messageViewController = (MessageViewController*)self.navigationController.visibleViewController;
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
    // TODO: change this once I implement the incoming call caller id
    [callViewController.parameters setObject:@"CHANGEME" forKey:@"username"];
    
    callViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:callViewController
                       animated:YES
                     completion:nil];
}

// not implemented yet
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (IBAction)start:(id)sender
{
    [self.device startSofia];
}

- (IBAction)stop:(id)sender
{
    [self.device stopSofia];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"invoke-settings"]) {
        SettingsTableViewController * settingsTableViewController = [segue destinationViewController];
        settingsTableViewController.device = self.device;
    }
    
    if ([segue.identifier isEqualToString:@"invoke-create-contact"]) {
        UINavigationController *contactUpdateNavigationController = [segue destinationViewController];
        ContactUpdateTableViewController * contactUpdateViewController =  [contactUpdateNavigationController.viewControllers objectAtIndex:0];
        contactUpdateViewController.delegate = self;
    }
    
}

- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[Utils contactCount] - 1 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
}

- (void)contactDetailsViewController:(ContactDetailsTableViewController*)contactDetailsViewController
           didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[Utils indexForContact:alias] inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
}


#pragma mark - Table view data source

/* No need to implement, we only have one section
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 0;
}
 */

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [Utils contactCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contact-reuse-identifier" forIndexPath:indexPath];
    
    // Configure the cell...
    NSArray * contact = [Utils contactForIndex:indexPath.row];
    cell.textLabel.text = [contact objectAtIndex:0];
    cell.detailTextLabel.text = [contact objectAtIndex:1];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // retrieve info for the selected contact
    NSArray * contact = [Utils contactForIndex:indexPath.row];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];

    // setup call view controller
    //CallViewController *callViewController = [[CallViewController alloc] init];
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:[contact objectAtIndex:0] forKey:@"alias"];
    [callViewController.parameters setObject:[contact objectAtIndex:1] forKey:@"username"];
    [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:@"video-enabled"];
    
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    // retrieve info for the selected contact
    NSArray * contact = [Utils contactForIndex:indexPath.row];

    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    
    ContactDetailsTableViewController *contactDetailsViewController = [storyboard instantiateViewControllerWithIdentifier:@"contact-details-controller"];
    //contactDetailsViewController.delegate = self;
    contactDetailsViewController.device = self.device;
    contactDetailsViewController.delegate = self;
    contactDetailsViewController.alias = [contact objectAtIndex:0];
    contactDetailsViewController.sipUri = [contact objectAtIndex:1];

    [[self navigationController] pushViewController:contactDetailsViewController animated:YES];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
