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

#include <unistd.h>

#import "ViewController.h"
#import "RestCommClient.h"
#import "SettingsNavigationController.h"
#import "SettingsViewController.h"
#import "CallViewController.h"
#import "MessageViewController.h"

extern char AOR[];
extern char REGISTRAR[];

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
@property (weak, nonatomic) IBOutlet UITextField *sipUriText;
@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    // auto correct off for SIP uri
    self.sipUriText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.isRegistered = NO;
    self.isInitialized = NO;

    // TODO: capabilityTokens aren't handled yet
    //NSString* capabilityToken = @"";
    
    self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSString stringWithUTF8String:AOR], @"aor",
                       @"1234", @"password",
                       nil];

    [self.parameters setObject:[NSString stringWithFormat:@"sip:%s", REGISTRAR] forKey:@"registrar"];
    
    // initialize RestComm Client by setting up an RCDevice
    self.device = [[RCDevice alloc] initWithParams:self.parameters delegate:self];
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
#ifdef DEBUG
    // set some defaults when in debug to avoid typing
    self.sipUriText.text = @"sip:1235@54.225.212.193:5080";
    //self.sipUriText.text = @"sip:alice@192.168.2.32:5080";
#else
    self.sipUriText.text = @"sip:1235@54.225.212.193:5080";
#endif

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(register:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unregister:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)hideKeyBoard
{
    // resign both to be sure
    [self.sipMessageText resignFirstResponder];
    [self.sipUriText resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// ---------- UI events
- (IBAction)sendPressed:(id)sender
{
    [self.parameters setObject:self.sipUriText.text forKey:@"username"];
    
    // send an instant message using RCDevice
    [self.device sendMessage:self.sipMessageText.text to:self.parameters];
    
    [self prependToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    // hide keyboard
    [self.sipMessageText endEditing:false];
}

- (IBAction)dialPressed:(id)sender
{
}


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
    [self.device updateParams:self.parameters];
    self.isRegistered = YES;
}

- (void)unregister:(NSNotification *)notification
{
    [self.device unlisten];
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
    [callViewController.parameters setObject:self.sipUriText.text forKey:@"username"];

    callViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:callViewController
                       animated:YES
                     completion:nil];
}

// not implemented yet
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

// helpers
- (void)prependToDialog:(NSString*)msg sender:(NSString*)sender
{
    if ([self.sipDialogText.text isEqualToString:@""]) {
        self.sipDialogText.text = [NSString stringWithFormat:@"%@: %@", sender, msg];
    }
    else {
        NSString* updatedDialog = [NSString stringWithFormat:@"%@\n%@: %@", self.sipDialogText.text, sender, msg];
        self.sipDialogText.text = [NSString stringWithString:updatedDialog];
    }
    
    // after appending scroll down too
    if (self.sipDialogText.text.length > 0 ) {
        NSRange bottom = NSMakeRange(self.sipDialogText.text.length - 1, 1);
        [self.sipDialogText scrollRangeToVisible:bottom];
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"invoke-call-controller"] || [segue.identifier isEqualToString:@"invoke-video-call-controller"]) {
        CallViewController *callViewController = [segue destinationViewController];
        callViewController.delegate = self;
        callViewController.device = self.device;
        callViewController.parameters = [[NSMutableDictionary alloc] init];
        [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
        [callViewController.parameters setObject:self.sipUriText.text forKey:@"username"];
        
        if ([segue.identifier isEqualToString:@"invoke-call-controller"]) {
            [callViewController.parameters setObject:[NSNumber numberWithBool:NO] forKey:@"video-enabled"];
        }
        else {
            [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:@"video-enabled"];
        }
    }
    if ([segue.identifier isEqualToString:@"invoke-settings"]) {
        SettingsViewController * settingsViewController = [segue destinationViewController];
        settingsViewController.device = self.device;
    }
    if ([segue.identifier isEqualToString:@"invoke-message-controller"]) {
        MessageViewController *callViewController = [segue destinationViewController];
        callViewController.device = self.device;
        callViewController.parameters = [[NSMutableDictionary alloc] init];
        [callViewController.parameters setObject:self.sipUriText.text forKey:@"username"];
    }
}

@end
