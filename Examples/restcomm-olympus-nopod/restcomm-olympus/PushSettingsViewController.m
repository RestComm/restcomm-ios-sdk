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

#import "PushSettingsViewController.h"
#import "Utils.h"
#import "RCDevice.h"
#import "AppDelegate.h"

@interface PushSettingsViewController () <UITextFieldDelegate, RCRegisterPushDelegate>

@property (unsafe_unretained, nonatomic) IBOutlet UITableViewCell *accountTVCell;
@property (unsafe_unretained, nonatomic) IBOutlet UITableViewCell *passwordTVCell;
@property (unsafe_unretained, nonatomic) IBOutlet UITableViewCell *domainTVCell;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushAccountText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushPasswordText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *pushDomainText;
@property UITextField * activeField;
@property (unsafe_unretained, nonatomic) IBOutlet UISwitch *enableSwitch;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

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
    
    self.navigationItem.title = @"Push Settings";
    
    //check is push server is enabled, if it is, eanble all input fields
    //otherwise disable them
    BOOL isServerEnabled = [Utils isServerEnabledForPushNotifications];
    [self.enableSwitch setOn:isServerEnabled];
    [self enableTextFields:isServerEnabled];
    
    //set input data
    self.pushAccountText.text = [Utils pushAccount];
    self.pushPasswordText.text = [Utils pushPassword];
    self.pushDomainText.text = [Utils pushDomain];
    
    //define spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
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
    if (self.enableSwitch.on){
        //trim settings inputs for spaces
        NSString * pushAccount = [self.pushAccountText.text stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]];
        
        NSString * pushPassword = [self.pushPasswordText.text stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]];
       
        NSString * pushDomain = [self.pushDomainText.text stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]];
       
        if ([pushAccount length] == 0){
            [Utils shakeTableViewCell:self.accountTVCell];
            return;
        }
        
        if ([pushPassword length] == 0){
            [Utils shakeTableViewCell:self.passwordTVCell];
            return;
        }
        
        if ([pushDomain length] == 0){
            [Utils shakeTableViewCell:self.domainTVCell];
            return;
        }
       
        [self showSpinner];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        
        //save account, password and domain
        [Utils updatePushAccount:pushAccount];
        [Utils updatePushPassword:pushPassword];
        [Utils updatePushDomain:pushDomain];
        
        //get certificate strings
        NSString *pushCertificatesPathPublic = [[NSBundle mainBundle] pathForResource:@"certificate_key_push" ofType:@"pem"];
        NSString *pushCertificatesPathPrivate = [[NSBundle mainBundle] pathForResource:@"rsa_private_key_push" ofType:@"pem"];
        
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                    kFriendlyName, RCPushFriendlyNameKey,
                                    pushAccount, RCRestcommAccountEmailKey,
                                    pushPassword, RCRestcommAccountPasswordKey,
                                    pushDomain, RCPushDomainKey,
                                    [Utils pushToken], RCPushTokenKey,
                                    pushCertificatesPathPublic, RCPushCertificatesPathPublicKey,
                                    pushCertificatesPathPrivate, RCPushCertificatesPathPrivateKey,
                                    [NSNumber numberWithBool:[Utils isSandbox]], RCPushIsSandbox, nil];
        
        AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
        RCDevice  *rcDevice = [appDelegate registerRCDevice];
        if (rcDevice){
            [rcDevice registerPushToken:dic delegate:self];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [Utils updateServerEnabledForPush:self.enableSwitch.on];
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(id)sender
{
    [self update];
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

- (void)enableTextFields:(BOOL)enable{
    self.pushAccountText.enabled = enable;
    self.pushPasswordText.enabled = enable;
    self.pushDomainText.enabled = enable;
    
    if (enable){
        self.pushAccountText.alpha = 1.0;
        self.pushPasswordText.alpha = 1.0;
        self.pushDomainText.alpha = 1.0;
    } else {
        self.pushAccountText.alpha = 0.5;
        self.pushPasswordText.alpha = 0.5;
        self.pushDomainText.alpha = 0.5;
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}
-(void) showSpinner{
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.view bringSubviewToFront:self.spinner];
    
    [self.spinner startAnimating];
}

-(void) hideSpinner{
    [self.spinner removeFromSuperview];
}

- (IBAction)onEnablePushNotifications:(id)sender {
    [self enableTextFields:self.enableSwitch.on];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

-(void)registeredForPush:(NSError *)error{
    [self hideSpinner];
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
     if (error){
         [Utils updateServerEnabledForPush:NO];
         UIAlertController * alert = [UIAlertController
                                      alertControllerWithTitle:@"Registering for push notification Error"
                                      message:[NSString stringWithFormat:@"Error while saving data to server. Error: %@", error]
                                      preferredStyle:UIAlertControllerStyleAlert];
         
         UIAlertAction *okAction = [UIAlertAction
                                    actionWithTitle:@"OK"
                                    style:UIAlertActionStyleDefault
                                    handler:nil];
         [alert addAction:okAction];
         [self presentViewController:alert animated:YES completion:nil];
         [self enableTextFields:NO];
         [self.enableSwitch setOn:NO];
     } else {
         [self dismissViewControllerAnimated:YES completion:nil];
     }
     NSLog(@"%@", error?error.description:@"app registered for push");
}

@end
