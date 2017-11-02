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


#import "MessageTableViewController.h"
#import "InputAccessoryProxyView.h"
//#import "RCUtilities.h"
#import "LocalMessageTableViewCell.h"
#import "RemoteMessageTableViewCell.h"
#import "Utils.h"
#import "CallViewController.h"

@interface MessageTableViewController ()
@property InputAccessoryProxyView * inputAccessoryProxyView;
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
//@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
// how many messages have been written in the table so far
//@property int messageCount;
// backing store for table
@property NSMutableArray * messages;
@property BOOL pendingError;
@end

@implementation MessageTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.messages = [[NSMutableArray alloc] init];
    // allocate and insert proxy view. Important: the proxy view cannot be part of the view hierarchy in the storyboard/xib.
    // It needs to be added dynamically
    self.inputAccessoryProxyView = [[InputAccessoryProxyView alloc]initWithFrame:[UIScreen mainScreen].bounds viewController:self];
    // see if this will work (used to be below sipDialogText)
    [self.view insertSubview:self.inputAccessoryProxyView belowSubview:self.tableView];
    
    // setup table view so that it allows its cell's height to grow depending on the content's intrinsic size
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44.0;
    
    // remove empty cells from tableview
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(proxyViewPressed)];
    [self.inputAccessoryProxyView addGestureRecognizer:recognizer];

    self.alias = [self.parameters objectForKey:@"alias"];
    self.username = [self.parameters objectForKey:RCUsername];
    
    if (self.alias) {
        // alias is set only for local messages
        self.navigationItem.title = self.alias;
    }
    else {
        self.navigationItem.title = self.username;
    }
    
    self.messages = [[Utils messagesForSipUri:self.username] mutableCopy];
    //self.messageCount = [self.messages count];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // Setup right bar button items. And since their default spacing is huge let's use custom view to remedy that
    UIView *videoCallBtnView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 38, 28)];
    UIButton *videoCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    [videoCallBtn addTarget:self action:@selector(doVideoCall) forControlEvents:UIControlEventTouchUpInside];
    [videoCallBtn setBackgroundImage:[UIImage imageNamed:@"camera-icon-28x28.png"] forState:UIControlStateNormal];
    [videoCallBtnView addSubview:videoCallBtn];
    UIBarButtonItem *btnVideoCall = [[UIBarButtonItem alloc] initWithCustomView:videoCallBtnView];
    
    UIView *audioCallBtnView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    UIButton *audioCallBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
    [audioCallBtn setBackgroundImage:[UIImage imageNamed:@"phone-icon-28x28.png"] forState:UIControlStateNormal];
    [audioCallBtn addTarget:self action:@selector(doAudioCall) forControlEvents:UIControlEventTouchUpInside];
    [audioCallBtnView addSubview:audioCallBtn];
    UIBarButtonItem *btnAudioCall = [[UIBarButtonItem alloc] initWithCustomView:audioCallBtnView];
    
    [self.navigationItem setRightBarButtonItems:@[btnAudioCall, btnVideoCall] animated:YES];
    
    //get sip uri (phone number) and save it as last peer for debug reporting
    [Utils saveLastPeer:[self.parameters objectForKey:RCUsername]];
}

- (void)proxyViewPressed {
    [self.inputAccessoryProxyView becomeFirstResponder];
}

- (void)doVideoCall
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    
    // setup call view controller
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:self.alias forKey:@"alias"];
    [callViewController.parameters setObject:self.username forKey:RCUsername];
    [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:RCVideoEnabled];
    
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)doAudioCall
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    
    // setup call view controller
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:self.alias forKey:@"alias"];
    [callViewController.parameters setObject:self.username forKey:RCUsername];
    [callViewController.parameters setObject:[NSNumber numberWithBool:NO] forKey:RCVideoEnabled];
    
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)populateChatHistory
{
    /*
    NSString *type = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"type"];
    if ([type isEqualToString:@"local"]) {
        LocalMessageTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"local-message-reuse-identifier" forIndexPath:indexPath];
        cell.senderText.text = [[self.messages objectAtIndex:indexPath.row] objectForKey:@"text"];
     */

}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.device.state == RCDeviceStateOffline) {
        self.pendingError = YES;
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"RCDevice not Connected"
                                     message:@"No connectivity"
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       [self alertOKTap];
                                   }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // we need that so that the accessory view shows up right away
    [self.inputAccessoryProxyView becomeFirstResponder];
    
    // Incoming text message just arrived
    if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"receive-message"]) {
        [self appendToDialog:[self.parameters objectForKey:@"message-text"] sender:self.username];
    }
    
    if ([self.messages count] > 0) {
        // scroll down to the last message
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)hideKeyBoard
{
    // resign both to be sure
    [self.sipMessageText resignFirstResponder];
}

// ---------- UI events
- (IBAction)sendMessagePressed:(id)sender
{
    NSMutableDictionary * parms = [NSMutableDictionary dictionaryWithObjectsAndKeys:self.username, RCUsername,
                                   self.sipMessageText.text, RCMessage, nil];
    
    // SIP custom headers: uncomment this to use SIP custom headers
    //[parms setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Value1", @"Key1", @"Value2", @"Key2", nil]
    //                    forKey:@"sip-headers"];
    
    // send an instant message using RCDevice
    if (![self.device sendMessage:parms]) {
        
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"RCDevice Error"
                                     message:@"Not connected"
                                     preferredStyle:UIAlertControllerStyleAlert];

        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       [self alertOKTap];
                                   }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    [self appendToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    [self.inputAccessoryProxyView becomeFirstResponder];
    // hide keyboard
    //[self.sipMessageText endEditing:false];
}

- (void)alertOKTap
{
    if (self.pendingError) {
        self.pendingError = NO;
        [self.navigationController popViewControllerAnimated:YES];
    }
}

// helpers
- (void)appendToDialog:(NSString*)msg sender:(NSString*)sender
{
    //NSString *username = [RCUtilities usernameFromUri:sender];
    // TODO: update the window title with the chat peer (do it once only)
    NSString * type = @"local";
    if (![sender isEqualToString:@"Me"]) {
        type = @"remote";
        // check if the remote party already exists and if not add it
        int index = [Utils indexForContact:self.username];
        if (index == -1) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"Updating Contacts"
                                         message:@"Sender not found in contacts; updating"
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            
            UIAlertAction *okAction = [UIAlertAction
                                       actionWithTitle:@"OK"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           [self alertOKTap];
                                       }];
            [alert addAction:okAction];
            [self presentViewController:alert animated:YES completion:nil];
           
            // not existing
            LocalContact *localContact = [[LocalContact alloc] initWithFirstName:sender lastName:@"" andPhoneNumbers:@[sender]];
            [Utils addContact:localContact];
            
            [self.delegate messageViewController:self didAddContactWithAlias:sender
                                          sipUri:sender];
        }
    }

    //NSLog(@"Adding new message to data store");
    // update the backing store and NSUserDefaults
    LocalMessage *message = [[LocalMessage alloc] initWithUsername:self.username message:msg type:type];
    [self.messages addObject:message];
    [Utils addMessage:message];
    
    [self.tableView beginUpdates];

    // trigger the new table row creation
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];
    
    if ([self.messages count] > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0]
                              atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"cellForRowAtIndexPath, row: %d, section: %d", indexPath.row, indexPath.section);
    LocalMessage *messageObj = [self.messages objectAtIndex:indexPath.row];
    if ([messageObj.type isEqualToString:@"local"]) {
        LocalMessageTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"local-message-reuse-identifier" forIndexPath:indexPath];
        cell.senderText.text = messageObj.message;
        cell.senderName.text = @"me";
        return cell;
    } else {
        RemoteMessageTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"remote-message-reuse-identifier" forIndexPath:indexPath];
        cell.senderText.text =  messageObj.message;
        cell.senderName.text = self.username;
        return cell;
    }
}

@end
