//
//  PushSettingsViewController.m
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 10/14/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import "PushSettingsViewController.h"
#import "Utils.h"
#import "RCDevice.h"
#import "AppDelegate.h"

@interface PushSettingsViewController () <UITextFieldDelegate, RCRegisterPushDelegate>
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushAccountText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushPasswordText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushDomainText;
@property UITextField * activeField;
@end

@implementation PushSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.activeField = nil;
    
    self.pushAccountText.delegate = self;
    self.pushPasswordText.delegate = self;
    self.pushDomainText.delegate = self;
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    
    // turn auto-correct in text fields
    self.pushAccountText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.pushPasswordText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.pushDomainText.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    [self registerForKeyboardNotifications];
    
    self.navigationItem.title = @"Push Notifications Settings";
}

-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        // back button was pressed.  We know this is true because self is no longer
        // in the navigation stack.
        [self update];
    }
    [super viewWillDisappear:animated];
}

- (void)hideKeyBoard
{
    // resign active first responder if available
    if (self.activeField) {
        [self.activeField resignFirstResponder];
    }
}

- (void)update
{
    
    //trim settings inputs for spaces
    NSString * pushAccount = [self.pushAccountText.text stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
    
    NSString * pushPassword = [self.pushPasswordText.text stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
   
    NSString * pushDomain = [self.pushDomainText.text stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
   
    if ([pushAccount length] == 0){
        [Utils shakeView:self.pushAccountText];
        return;
    }
    
    if ([pushPassword length] == 0){
        [Utils shakeView:self.pushPasswordText];
        return;
    }
    
    if ([pushDomain length] == 0){
        [Utils shakeView:self.pushDomainText];
        return;
    }
   
    //get certificate strings
    NSString *pushCertificatesPathPublic = [[NSBundle mainBundle] pathForResource:@"certificate_key_push" ofType:@"pem"];
    NSString *pushCertificatesPathPrivate = [[NSBundle mainBundle] pathForResource:@"rsa_private_key_push" ofType:@"pem"];
    
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                kFriendlyName, @"friendly-name",
                                pushAccount, @"rescomm-account-email",
                                pushPassword, @"password",
                                pushDomain, @"push-domain",
                                [Utils pushToken], @"token",
                                pushCertificatesPathPublic, @"push-certificate-public-path",
                                pushCertificatesPathPrivate, @"push-certificate-private-path",
                                [NSNumber numberWithBool:NO], @"is-sandbox", nil];
    
    AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    RCDevice  *rcDevice = [appDelegate registerRCDevice];
    if (rcDevice){
        [rcDevice registerPushToken:dic delegate:self];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(id)sender
{
    [self update];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}


- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    _activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    _activeField = nil;
}


- (void)keyboardWasShown:(NSNotification*)aNotification
{
    CGSize kbSize = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    UIEdgeInsets edgeInsets = [self.tableView contentInset];
    edgeInsets.bottom += kbSize.height;
    UIEdgeInsets scrollInsets = [self.tableView scrollIndicatorInsets];
    scrollInsets.bottom += kbSize.height;
    
    [UIView animateWithDuration:duration animations:^{
        [self.tableView setContentInset:edgeInsets];
        [self.tableView setScrollIndicatorInsets:scrollInsets];
    }];
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    CGSize kbSize = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSTimeInterval duration = [[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    UIEdgeInsets edgeInsets = [self.tableView contentInset];
    edgeInsets.bottom -= kbSize.height;
    UIEdgeInsets scrollInsets = [self.tableView scrollIndicatorInsets];
    scrollInsets.bottom -= kbSize.height;
    
    
    [UIView animateWithDuration:duration animations:^{
        [self.tableView setContentInset:edgeInsets];
        [self.tableView setScrollIndicatorInsets:scrollInsets];
    }];

}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

-(void)registeredForPush:(NSError *)error{
    NSLog(@"%@", error?error.description:@"app registered for push");
}

@end
