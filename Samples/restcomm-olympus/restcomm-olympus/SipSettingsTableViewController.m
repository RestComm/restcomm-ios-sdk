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
#import "SipSettingsTableViewController.h"
#import "MainNavigationController.h"
#import "Utils.h"

@interface SipSettingsTableViewController ()
@property (weak, nonatomic) IBOutlet UITextField *aorText;
@property (weak, nonatomic) IBOutlet UITextField *registrarText;
@property (weak, nonatomic) IBOutlet UITextField *passwordText;
@property UITextField * activeField;
@end

@implementation SipSettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _activeField = nil;
    _aorText.delegate = self;
    _registrarText.delegate = self;
    _passwordText.delegate = self;
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];

    // turn auto-correct in text fields; doesn't help with SIP uris
    self.aorText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.registrarText.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    [self registerForKeyboardNotifications];
    
    self.navigationItem.title = @"SIP Settings";
    
    // mail screen (i.e. contacts) should be at the bottom of the stack
    self.delegate = [self.navigationController.viewControllers objectAtIndex:0];
}

// Call this method somewhere in your view controller setup code.
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

// Called when the UIKeyboardDidShowNotification is sent.
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

- (void)viewWillAppear:(BOOL)animated
{
    self.aorText.text = [Utils sipIdentification];
    self.registrarText.text = [Utils sipRegistrar];
    self.passwordText.text = [Utils sipPassword]; 
    // Latest:
    //UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style: UIBarButtonItemStyleBordered target:self action:@selector(backPressed)];
    //self.navigationItem.leftBarButtonItem = backButton;
}

-(void) viewWillDisappear:(BOOL)animated {
    if ([self.navigationController.viewControllers indexOfObject:self] == NSNotFound) {
        // back button was pressed.  We know this is true because self is no longer
        // in the navigation stack.
        [self update];
    }
    [super viewWillDisappear:animated];
}

- (IBAction)backPressed
{
    //[self dismissViewControllerAnimated:YES completion:nil]; // ios 6
    [self update];
}

- (void)hideKeyBoard
{
    // resign active first responder if available
    if (_activeField) {
        [_activeField resignFirstResponder];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)update
{
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    // always update registrar to make sure registraless is handled properly
    bool update = true;
    [params setObject:@"" forKey:@"registrar"];
    [Utils updateSipRegistrar:self.registrarText.text];
    if (![self.aorText.text isEqualToString:@""]) {
        [params setObject:self.aorText.text forKey:@"aor"];
        [Utils updateSipIdentification:self.aorText.text];
        //update = true;
    }
    if (![self.registrarText.text isEqualToString:@""]) {
        //[params setObject:[NSString stringWithFormat:@"sip:%@", self.registrarText.text] forKey:@"registrar"];
        [params setObject:[NSString stringWithFormat:@"%@", self.registrarText.text] forKey:@"registrar"];
        //[Utils updateSipRegistrar:self.registrarText.text];
        //update = true;
    }
    if (![self.passwordText.text isEqualToString:@""]) {
        [params setObject:self.passwordText.text forKey:@"password"];
        [Utils updateSipPassword:self.passwordText.text];
        //update = true;
    }
        
    if (update) {
        if ([self.device updateParams:params]) {
            [self.delegate sipSettingsTableViewController:self didUpdateRegistrationWithString:self.registrarText.text];
        }
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
