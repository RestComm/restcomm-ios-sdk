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

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
@property (weak, nonatomic) IBOutlet UITextField *sipUriText;
@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
@property (weak, nonatomic) IBOutlet UIButton *answerButton;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // auto correct off for SIP uri
    self.sipUriText.autocorrectionType = UITextAutocorrectionTypeNo;

    // TODO: capabilityTokens aren't handled yet
    NSString* capabilityToken = @"";
    
    // let's hardcode a template for RestComm, so that only the username is needed in our methods below
    //self.parameters = [NSMutableDictionary dictionaryWithObject:@"sip:%@@192.168.2.32:5080" forKey:@"uas-uri-template"];
    self.parameters = [[NSMutableDictionary alloc] init];
    
    // #INIT-CLIENT: initialize RestComm Client by setting up an RCDevice
    self.device = [[RCDevice alloc] initWithCapabilityToken:capabilityToken delegate:self];

    TabBarController * tabBarController = (TabBarController *)self.tabBarController;
    // add a reference of RCDevice to our tab controller so that Settings controller can utilize it
    tabBarController.device = self.device;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    [self prepareSounds];
#ifdef DEBUG
    // set some defaults when in debug to avoid typing
    //self.sipUriText.text = @"sip:alice@23.23.228.238:5080";
    //self.sipUriText.text = @"sip:1234@192.168.2.32:5080";
    self.sipUriText.text = @"sip:john@192.168.2.20";
#endif
    
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
    
    // #SEND-MSG: send an instant message using RCDevice
    [self.device sendMessage:self.sipMessageText.text to:self.parameters];
    
    [self prependToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    // hide keyboard
    [self.sipMessageText endEditing:false];
}

- (IBAction)dialPressed:(id)sender
{
    [self.parameters setObject:self.sipUriText.text forKey:@"username"];
    
    // #START-CONNECTION: call the other party
    self.connection = [self.device connect:self.parameters delegate:self];
    //self.sipUriText.text = @"";

    // hide keyboard
    [self.sipUriText endEditing:false];
}

- (IBAction)answerPressed:(id)sender
{
    [self.ringingPlayer stop];
    self.ringingPlayer.currentTime = 0.0;    

    [self.pendingIncomingConnection accept];
    self.connection = self.pendingIncomingConnection;
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)declinePressed:(id)sender
{
    [self.ringingPlayer stop];
    self.ringingPlayer.currentTime = 0.0;
    
    // #REJECT: reject the pending RCConnection
    [self.pendingIncomingConnection reject];
    
    self.pendingIncomingConnection = nil;
    
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)hangUpPressed:(id)sender
{
    // disconnect the established RCConnection
    [self.connection disconnect];
    
    self.connection = nil;
}

- (IBAction)cancelPressed:(id)sender
{
    [self.connection disconnect];
    self.connection = nil;
}

// ---------- Delegate methods for RC Device
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    
}

// optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    
}

// #RECV-MSG: received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message
{
    [self.messagePlayer play];
    [self prependToDialog:message sender:@"alice"];
}

// #RECV-CONNECTION: 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
    [self.ringingPlayer play];
    self.pendingIncomingConnection = connection;
    
    // let's add some animation to get users attention (alpha)
    CAKeyframeAnimation * alphaAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    
    alphaAnimation.values = [NSArray arrayWithObjects:@1.0F, @1.0F, @0.0F, @0.0F, @1.0F, @1.0F, nil];
    alphaAnimation.keyTimes = [NSArray arrayWithObjects:@0.0F, @0.3F, @0.4F, @0.7F, @0.8F, @1.0F, nil];
    
    CAAnimationGroup* group = [CAAnimationGroup animation];
    // repeat forever
    group.repeatCount = HUGE_VALF;
    group.duration = 1.0;
    group.animations = [NSArray arrayWithObjects:alphaAnimation, nil];
    
    [self.answerButton.layer addAnimation:group forKey:@"flash-animation"];
}

// not implemented yet
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

// ---------- Delegate methods for RC Connection
// not implemented yet
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error
{
    
}

// optional
// 'ringing' for outgoing connections
- (void)connectionDidStartConnecting:(RCConnection*)connection
{
    NSLog(@"connectionDidStartConnecting");
}

- (void)connectionDidConnect:(RCConnection*)connection
{
    NSLog(@"connectionDidConnect");
}

- (void)connectionDidDisconnect:(RCConnection*)connection
{
    
}

// helpers
- (void)prependToDialog:(NSString*)msg sender:(NSString*)sender
{
    NSString* updatedDialog = [NSString stringWithFormat:@"%@: %@\n%@", sender, msg, self.sipDialogText.text];
    self.sipDialogText.text = [NSString stringWithString:updatedDialog];
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
    
    // ringing
    filename = @"ringing.mp3";
    // we are assuming the extension will always be the last 3 letters of the filename
    file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                                      ofType:[filename substringFromIndex:[filename length] - 3]];
    
    self.ringingPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
    if (!self.ringingPlayer) {
        NSLog(@"Error: %@", [error description]);
        return;
    }
    self.ringingPlayer.numberOfLoops = -1; // repeat forever
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

@end
