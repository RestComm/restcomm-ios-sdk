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
#import "TabBarController.h"
#import "CallViewController.h"

extern char AOR[];
extern char REGISTRAR[];

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
@property (weak, nonatomic) IBOutlet UITextField *sipUriText;
@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
//@property (weak, nonatomic) IBOutlet UIButton *answerButton;
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
    NSString* capabilityToken = @"";
    
    self.parameters = [[NSMutableDictionary alloc] init];
    
    // initialize RestComm Client by setting up an RCDevice
    self.device = [[RCDevice alloc] initWithCapabilityToken:capabilityToken delegate:self];
    //self.connection = nil;

    TabBarController * tabBarController = (TabBarController *)self.tabBarController;
    // add a reference of RCDevice to our tab controller so that Settings controller can utilize it
    tabBarController.viewController = self;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    [self prepareSounds];
#ifdef DEBUG
    // set some defaults when in debug to avoid typing
    //self.sipUriText.text = @"sip:1235@54.225.212.193:5080";
    self.sipUriText.text = @"sip:alice@192.168.2.32:5080";
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

/**/
- (IBAction)dialPressed:(id)sender
{
    //[self performSegueWithIdentifier:@"invoke-call-controller" sender:self];
    // start the call
    /*
    CallViewController *callViewController =
    [[CallViewController alloc] initWithDevice:self.device andParams:[NSDictionary dictionaryWithObject:self.sipUriText.text
                                                                                                 forKey:@"username"]];
    //videoCallViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:callViewController
                       animated:YES
                     completion:nil];
     */

    
    //[self.parameters setObject:self.sipUriText.text forKey:@"username"];
    
    // TODO: open the call view
    /*
    // call the other party
    if (self.connection) {
        NSLog(@"Connection already ongoing");
        return;
    }
    self.connection = [self.device connect:self.parameters delegate:self];
    // hide keyboard
    [self.sipUriText endEditing:false];
     */
}

/*
- (IBAction)answerPressed:(id)sender
{
    if (self.ringingPlayer.isPlaying) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }

    if (self.pendingIncomingConnection) {
        [self.pendingIncomingConnection accept];
        self.connection = self.pendingIncomingConnection;
    }
}

- (IBAction)declinePressed:(id)sender
{
    if (self.ringingPlayer.isPlaying) {
        [self.ringingPlayer stop];
        self.ringingPlayer.currentTime = 0.0;
    }
    
    if (self.pendingIncomingConnection) {
        // reject the pending RCConnection
        [self.pendingIncomingConnection reject];
        self.pendingIncomingConnection = nil;
    }
}

- (IBAction)hangUpPressed:(id)sender
{
    [self disconnect];
}

- (IBAction)cancelPressed:(id)sender
{
    if (self.connection) {
        [self.connection disconnect];
        self.connection = nil;
        self.pendingIncomingConnection = nil;
    }
}

- (void)disconnect
{
    if (self.connection) {
        [self.connection disconnect];
        
        self.connection = nil;
        self.pendingIncomingConnection = nil;
    }
}
 */
- (IBAction)registerPressed:(id)sender
{
}

 
- (void)register:(NSNotification *)notification
{
    if (self.device && self.isInitialized && !self.isRegistered) {
        [self register];
    }
}

- (void)register
{
    // try to register when coming up with the existing settings
    [self.parameters setObject:[NSString stringWithUTF8String:AOR] forKey:@"aor"];
    [self.parameters setObject:[NSString stringWithFormat:@"sip:%s", REGISTRAR] forKey:@"registrar"];
    [self.parameters setObject:@"1234" forKey:@"password"];
    
    // update our parms
    [self.device updateParams:self.parameters];
    self.isRegistered = YES;
}

- (void)unregister:(NSNotification *)notification
{
    //[self disconnect];
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
    [self register];
    self.isInitialized = YES;
}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message withParams:(NSDictionary *)params
{
    [self.messagePlayer play];
    [self prependToDialog:message sender:[params objectForKey:@"from"]];
}

// 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
    // TODO: open call view
    //[self.ringingPlayer play];
    //self.pendingIncomingConnection = connection;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.pendingIncomingConnection = connection;
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
        self.sipDialogText.text = [NSString stringWithFormat:@"%@", msg];
        //self.sipDialogText.text = [self.sipDialogText.text stringByAppendingString: //stringWithString:updatedDialog];
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

- (void)prepareSounds
{
    // message
    NSString * filename = @"message.mp3";
    // we are assuming the extension will always be the last 3 letters of the filename
    NSString * file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                                      ofType:[filename substringFromIndex:[filename length] - 3]];
    
    NSError *error;
    self.messagePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
    if (!self.messagePlayer) {
        NSLog(@"Error: %@", [error description]);
        return;
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
    if ([segue.identifier isEqualToString:@"invoke-call-controller"]) {
        CallViewController *callViewController = [segue destinationViewController];
        callViewController.delegate = self;
        callViewController.device = self.device;
        callViewController.parameters = [[NSMutableDictionary alloc] init];
        [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
        [callViewController.parameters setObject:self.sipUriText.text forKey:@"username"];
    }
    
}

@end
