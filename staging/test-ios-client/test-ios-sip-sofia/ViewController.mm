//
//  ViewController.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include <unistd.h>

#import "ViewController.h"
#import "RestCommClient.h"

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

    // TODO: capabilityTokens aren't handled yet
    NSString* capabilityToken = @"";
    
    // let's hardcode a template for RestComm, so that only the username is needed in our methods below
    self.parameters = [NSMutableDictionary dictionaryWithObject:@"sip:%@@192.168.2.30:5080" forKey:@"uas-uri-template"];
    self.device = [[RCDevice alloc] initWithCapabilityToken:capabilityToken delegate:self];
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
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
    // hardcode Alice for now
    [self.parameters setObject:@"alice" forKey:@"username"];
    [self.device sendMessage:self.sipMessageText.text to:self.parameters];
    [self prependToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    // hide keyboard
    [self.sipMessageText endEditing:false];
}

- (IBAction)dialPressed:(id)sender
{
    [self.parameters setObject:self.sipUriText.text forKey:@"username"];
    self.connection = [self.device connect:self.parameters delegate:self];
    self.sipUriText.text = @"";

    // hide keyboard
    [self.sipUriText endEditing:false];
}

- (IBAction)answerPressed:(id)sender
{
    [self.pendingIncomingConnection accept];
    self.connection = self.pendingIncomingConnection;
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)declinePressed:(id)sender
{
    [self.pendingIncomingConnection reject];
    self.pendingIncomingConnection = nil;
    
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)hangUpPressed:(id)sender
{
    [self.connection disconnect];
    self.connection = nil;
}

- (IBAction)cancelPressed:(id)sender
{
    // not sure such functionality exists in RestCommClient
    [self.connection disconnect];
    self.connection = nil;
}

- (IBAction)updateParamsPressed:(id)sender {
    [self.device updateParams];
}

// ---------- Delegate methods for RC Device
// call just arrived; let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    
}

// optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    
}

- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message
{
    [self prependToDialog:message sender:@"Alice"];
}

// 'ringing' for incoming connections
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
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

- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

// ---------- Delegate methods for RC Connection
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

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

@end
