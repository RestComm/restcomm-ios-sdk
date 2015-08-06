//
//  MessageViewController.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 8/3/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "MessageViewController.h"
#import "InputAccessoryProxyView.h"

@interface MessageViewController ()
@property (weak, nonatomic) IBOutlet UIButton *buttonPlaceholder;
@property InputAccessoryProxyView * inputAccessoryProxyView;
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
@end

@implementation MessageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    // allocate and insert proxy view. Important: the proxy view cannot be part of the view hierarchy in the storyboard/xib.
    // It needs to be added dynamically
    self.inputAccessoryProxyView = [[InputAccessoryProxyView alloc]initWithFrame:[UIScreen mainScreen].bounds viewController:self];
    [self.view insertSubview:self.inputAccessoryProxyView belowSubview:self.sipDialogText];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(proxyViewPressed)];
    [self.inputAccessoryProxyView addGestureRecognizer:recognizer];
}

- (void)proxyViewPressed {
    [self.inputAccessoryProxyView becomeFirstResponder];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // we need that so that the accessory view shows up right away
    [self.inputAccessoryProxyView becomeFirstResponder];
    
    // Incoming text message just arrived
    if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"receive-message"]) {
        [self appendToDialog:[self.parameters objectForKey:@"message-text"] sender:[self.parameters objectForKey:@"username"]];
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
    // send an instant message using RCDevice
    [self.device sendMessage:self.sipMessageText.text
                          to:[NSDictionary dictionaryWithObject:[self.parameters objectForKey:@"username"] forKey:@"username"]];
    
    [self appendToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    [self.inputAccessoryProxyView becomeFirstResponder];
    // hide keyboard
    //[self.sipMessageText endEditing:false];
}

// helpers
- (void)appendToDialog:(NSString*)msg sender:(NSString*)sender
{
    // simplify the sender sip uri
    NSString* schemaUsername = nil;
    NSString* username = nil;
    if ([sender rangeOfString:@"@"].location != NSNotFound) {
        schemaUsername = [sender componentsSeparatedByString:@"@"][0];
        if (schemaUsername && [schemaUsername rangeOfString:@":"].location != NSNotFound) {
            username = [schemaUsername componentsSeparatedByString:@":"][1];
        }
    }
    else {
        username = sender;
    }
    
    if ([self.sipDialogText.text isEqualToString:@""]) {
        self.sipDialogText.text = [NSString stringWithFormat:@"%@: %@\n", username, msg];
    }
    else {
        NSString* updatedDialog = [NSString stringWithFormat:@"%@\n%@: %@\n", self.sipDialogText.text, username, msg];
        self.sipDialogText.text = [NSString stringWithString:updatedDialog];
    }
    
    // after appending scroll down too
    if (self.sipDialogText.text.length > 0 ) {
        NSRange bottom = NSMakeRange(self.sipDialogText.text.length - 1, 1);
        // disable animation cause it messes experientce; we always start out at the beginning and get scrolled down all the way
        [UIView setAnimationsEnabled:NO];
        [self.sipDialogText scrollRangeToVisible:bottom];
        [UIView setAnimationsEnabled:YES];
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

@end
