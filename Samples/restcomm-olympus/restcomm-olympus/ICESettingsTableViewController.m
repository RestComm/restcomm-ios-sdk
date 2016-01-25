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
#import "Utils.h"

@interface ICESettingsTableViewController ()
@property (weak, nonatomic) IBOutlet UITextField *turnUrlText;
@property (weak, nonatomic) IBOutlet UITextField *turnUsernameText;
@property (weak, nonatomic) IBOutlet UITextField *turnPasswordText;
@property (unsafe_unretained, nonatomic) IBOutlet UISlider *timeoutSlider;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *secondsLabel;
@end

@implementation ICESettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    
    // turn auto-correct in text fields; doesn't help with SIP uris
    self.turnUrlText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.turnUsernameText.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];
    
    self.navigationItem.title = @"ICE Settings";
}

- (void)viewWillAppear:(BOOL)animated
{
    self.turnUrlText.text = [Utils turnUrl];
    self.turnUsernameText.text = [Utils turnUsername];
    self.turnPasswordText.text = [Utils turnPassword];
    [self.timeoutSlider setValue:[[Utils turnCandidateTimeout] floatValue]];
    self.secondsLabel.text = [Utils turnCandidateTimeout];
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
    // resign both to be sure
    [self.turnUrlText resignFirstResponder];
    [self.turnUsernameText resignFirstResponder];
    [self.turnPasswordText resignFirstResponder];
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
    [Utils updateTurnUrl:self.turnUrlText.text];
    [params setObject:self.turnUrlText.text forKey:@"turn-url"];
    [Utils updateTurnUsername:self.turnUsernameText.text];
    [params setObject:self.turnUsernameText.text forKey:@"turn-username"];
    [Utils updateTurnPassword:self.turnPasswordText.text];
    [params setObject:self.turnPasswordText.text forKey:@"turn-password"];
    [Utils updateTurnCandidateTimeout:self.secondsLabel.text];
    [params setObject:self.secondsLabel.text forKey:@"turn-candidate-timeout"];

    [self.device updateParams:params];
}

- (IBAction)sliderChanged:(id)sender
{
    self.secondsLabel.text = [NSString stringWithFormat:@"%d", (int)self.timeoutSlider.value];
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
