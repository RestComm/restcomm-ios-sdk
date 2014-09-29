//
//  ViewController.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include <unistd.h>

#import "ViewController.h"
#import "SofiaSIP.h"

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
    self.sofiaSIP = [[SofiaSIP alloc] initWithController:self];
    [self.sofiaSIP initialize];
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
}

-(void)hideKeyBoard
{
    [self.sipMessageText resignFirstResponder];
    [self.sipUriText resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendPressed:(id)sender
{
    // TODO: hard-code for now
    [self.sofiaSIP sendMessage:self.sipMessageText.text to:@"sip:alice@192.168.2.30:5080"];
    [self prependToDialog:self.sipMessageText.text sender:@"Me"];
    //NSString* updatedDialog = [NSString stringWithFormat:@"Me: %@\n%@", self.sipMessageText.text, self.sipDialogText.text];
    //self.sipDialogText.text = [NSString stringWithString:updatedDialog];
    self.sipMessageText.text = @"";

    // hide keyboard
    [self.sipMessageText endEditing:false];
}

- (IBAction)dialPressed:(id)sender
{
    // TODO: hard-code for now
    NSString* uri = [NSString stringWithFormat:@"sip:%@@192.168.2.30:5080", self.sipUriText.text];
    [self.sofiaSIP invite:uri];
    //[self.sofiaSIP generic:self.sipMessageText.text];
    self.sipUriText.text = @"";

    // hide keyboard
    [self.sipUriText endEditing:false];
}

- (IBAction)answerPressed:(id)sender
{
    [self.sofiaSIP answer];
    [self.answerButton.layer removeAllAnimations];
    //[self.answerButton setTitle:@"Hang up" forState:UIControlStateNormal];
}

- (IBAction)declinePressed:(id)sender
{
    [self.sofiaSIP decline];
    [self.answerButton.layer removeAllAnimations];
}

- (IBAction)hangUpPressed:(id)sender
{
    [self.sofiaSIP bye];
}

- (void)incomingCall
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

- (void)incomingMsg:(NSString*)msg
{
    [self prependToDialog:msg sender:@"Alice"];
}

// helpers
- (void)prependToDialog:(NSString*)msg sender:(NSString*)sender
{
    NSString* updatedDialog = [NSString stringWithFormat:@"%@: %@\n%@", sender, msg, self.sipDialogText.text];
    self.sipDialogText.text = [NSString stringWithString:updatedDialog];
}


@end
