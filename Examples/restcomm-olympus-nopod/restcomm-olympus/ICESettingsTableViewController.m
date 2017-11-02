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

#import "ICESettingsTableViewController.h"
#import "MainNavigationController.h"
#import "ICESettingsNavigationController.h"
#import "Utils.h"
#import "AppDelegate.h"

@interface ICESettingsTableViewController ()
@property (weak, nonatomic) IBOutlet UITextField *turnUrlText;
@property (weak, nonatomic) IBOutlet UITextField *turnUsernameText;
@property (weak, nonatomic) IBOutlet UITextField *turnPasswordText;
//@property (unsafe_unretained, nonatomic) IBOutlet UISlider *timeoutSlider;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *secondsLabel;
@property UITextField * activeField;
@property (weak, nonatomic) IBOutlet UISwitch *switchOnOff;
@end

/* Note that the reason we are using a separate Navigation Controller for this controller is that there's an issue with iOS and Bar Button items don't show right when on a modal controller
 */

@implementation ICESettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _activeField = nil;

    _turnUrlText.delegate = self;
    _turnUsernameText.delegate = self;
    _turnPasswordText.delegate = self;
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    
    // turn auto-correct in text fields; doesn't help with SIP uris
    self.turnUrlText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.turnUsernameText.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    [self registerForKeyboardNotifications];
    
    AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    self.device = appDelegate.device;
    
    self.navigationItem.title = @"ICE Settings";
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
    /*
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
    
    CGRect aRect = self.tableView.bounds;
    aRect.size.height -= kbSize.height;
    CGRect activeRect = [_activeField convertRect:_activeField.frame toView:self.tableView];
    
    if (!CGRectContainsPoint(aRect, activeRect.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, activeRect.origin.y-kbSize.height+10);
        [self.tableView setContentOffset:scrollPoint animated:YES];
    }
    */
    /*
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, _activeField.frame.origin) ) {
        [self.tableView scrollRectToVisible:_activeField.frame animated:YES];
    }
     */
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
    /*
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
     */
}

- (void)viewWillAppear:(BOOL)animated
{
    self.turnUrlText.text = [Utils turnUrl];
    self.turnUsernameText.text = [Utils turnUsername];
    self.turnPasswordText.text = [Utils turnPassword];
    //[self.timeoutSlider setValue:[[Utils turnCandidateTimeout] floatValue]];
    self.secondsLabel.text = [Utils turnCandidateTimeout];
    [self.switchOnOff setOn:[Utils turnEnabled] animated:NO];
    
    [self updateUIBasedOnSwitch];
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

/*
- (IBAction)backPressed
{
    //[self dismissViewControllerAnimated:YES completion:nil]; // ios 6
    [self update];
}
 */

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
    // TODO: proper way to do this is to update only when a value has changed compared to the value when ICE Settings screen was opened
    // For now let's save always
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    [Utils updateTurnEnabled:self.switchOnOff.on];
    [params setObject:@(self.switchOnOff.on) forKey:RCTurnEnabledKey];
    [Utils updateTurnUrl:self.turnUrlText.text];
    [params setObject:self.turnUrlText.text forKey:RCTurnUrlKey];
    [Utils updateTurnUsername:self.turnUsernameText.text];
    [params setObject:self.turnUsernameText.text forKey:RCTurnUsernameKey];
    [Utils updateTurnPassword:self.turnPasswordText.text];
    [params setObject:self.turnPasswordText.text forKey:RCTurnPasswordKey];
    //[Utils updateTurnCandidateTimeout:self.secondsLabel.text];
    //[params setObject:self.secondsLabel.text forKey:@"turn-candidate-timeout"];

    [self.device updateParams:params];
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
    //[self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)savePressed:(id)sender
{
    /*
    if ([self.aorText.text isEqualToString:@""] || [self.registrarText.text isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Validation Error"
                                                        message:@"Username and Domain fields are mandatory"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
     */
    [self update];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)switchChanged:(id)sender {
    [self updateUIBasedOnSwitch];
}

- (void)updateUIBasedOnSwitch
{
    if (self.switchOnOff.on) {
        [self.turnUrlText setEnabled:YES];
        self.turnUrlText.alpha = 1.0;
        [self.turnUsernameText setEnabled:YES];
        self.turnUsernameText.alpha = 1.0;
        [self.turnPasswordText setEnabled:YES];
        self.turnPasswordText.alpha = 1.0;
    }
    else {
        float disabledAlpha = 0.5;
        [self.turnUrlText setEnabled:NO];
        self.turnUrlText.alpha = disabledAlpha;
        //[self.turnUrlText setUserInteractionEnabled:NO];
        [self.turnUsernameText setEnabled:NO];
        self.turnUsernameText.alpha = disabledAlpha;
        [self.turnPasswordText setEnabled:NO];
        self.turnPasswordText.alpha = disabledAlpha;
    }
}

/*
- (IBAction)sliderChanged:(id)sender
{
    self.secondsLabel.text = [NSString stringWithFormat:@"%d", (int)self.timeoutSlider.value];
}
 */

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

@end
