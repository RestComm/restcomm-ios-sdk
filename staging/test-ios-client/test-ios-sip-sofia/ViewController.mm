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
    // Do any additional setup after loading the view, typically from a nib.
    NSString* capabilityToken = @"";
    self.parameters = [NSMutableDictionary dictionaryWithObject:@"sip:%@@192.168.2.30:5080" forKey:@"uri-call-template"];
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
    // For starters RestCommClient doesn't support messages
    /*
    // TODO: hard-code for now
    [self.sipManager message:self.sipMessageText.text to:@"sip:alice@192.168.2.30:5080"];
    [self prependToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";

    // hide keyboard
    [self.sipMessageText endEditing:false];
     */
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
    //[self.sipManager answer];
    //[self.connection accept];
    [self.pendingIncomingConnection accept];
    self.connection = self.pendingIncomingConnection;
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)declinePressed:(id)sender
{
    //[self.sipManager decline];
    [self.connection reject];
    
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)hangUpPressed:(id)sender
{
    //[self.sipManager bye];
    [self.connection disconnect];
}

- (IBAction)cancelPressed:(id)sender
{
    // not sure such functionality exists in RestCommClient
    //[self.sipManager cancel];
}

// ---------- delegate methods for RC Device
// call just arrived; let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    
}

// optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
    
}

- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
    self.pendingIncomingConnection = connection;
    // animate alpha
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

// ---------- delegate methods for RC Connection
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error
{
    
}

// optional
- (void)connectionDidStartConnecting:(RCConnection*)connection
{
    
}

- (void)connectionDidConnect:(RCConnection*)connection
{
    
}

- (void)connectionDidDisconnect:(RCConnection*)connection
{
    
}

/*
- (void)callArrived:(SipManager *)sipManager
{
    // animate alpha
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

- (void)messageArrived:(SipManager *)sipManager withData:(NSString *)msg
{
    [self prependToDialog:msg sender:@"Alice"];
}
*/
 
// helpers
- (void)prependToDialog:(NSString*)msg sender:(NSString*)sender
{
    NSString* updatedDialog = [NSString stringWithFormat:@"%@: %@\n%@", sender, msg, self.sipDialogText.text];
    self.sipDialogText.text = [NSString stringWithString:updatedDialog];
}


@end
