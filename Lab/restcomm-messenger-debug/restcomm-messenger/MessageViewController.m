//
//  MessageViewController.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 8/3/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "MessageViewController.h"

@interface MessageViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;
@property (weak, nonatomic) IBOutlet UITextView *sipDialogText;
@end

@implementation MessageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration:0.0f];
    self.view.frame = CGRectOffset(self.view.frame, 0, -kbSize.height);
    [UIView commitAnimations];
    /*
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        [self.scrollView scrollRectToVisible:activeField.frame animated:YES];
    }
     */
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    [UIView beginAnimations: @"anim" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration:0.0f];
    self.view.frame = CGRectOffset(self.view.frame, 0, kbSize.height);
    [UIView commitAnimations];

    //UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    //scrollView.contentInset = contentInsets;
    //scrollView.scrollIndicatorInsets = contentInsets;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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
- (IBAction)sendPressed:(id)sender
{
    //[self.parameters setObject:[self.parameters objectForKey:@"message-target"]
    //                    forKey:@"username"];
    
    // send an instant message using RCDevice
    [self.device sendMessage:self.sipMessageText.text
                          to:[NSDictionary dictionaryWithObject:[self.parameters objectForKey:@"username"] forKey:@"username"]];
    
    [self appendToDialog:self.sipMessageText.text sender:@"Me"];
    self.sipMessageText.text = @"";
    
    // hide keyboard
    [self.sipMessageText endEditing:false];
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
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
