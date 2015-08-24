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

#import "SettingsViewController.h"
#import "SettingsNavigationController.h"

char AOR[] = "sip:bob@telestax.com";
// elastic
char REGISTRAR[] = "54.225.212.193:5080";
//char REGISTRAR[] = "192.168.2.32:5080";


@interface SettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *aorText;
@property (weak, nonatomic) IBOutlet UITextField *registrarText;
@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;
@end

@implementation SettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // turn auto-correct in text fields; doesn't help with SIP uris
    self.aorText.autocorrectionType = UITextAutocorrectionTypeNo;
    self.registrarText.autocorrectionType = UITextAutocorrectionTypeNo;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(hideKeyBoard)];
    
    [self.view addGestureRecognizer:tapGesture];

    // set some defaults when in debug to avoid typing
    self.aorText.text = [NSString stringWithUTF8String:AOR];
    self.registrarText.text = [NSString stringWithUTF8String:REGISTRAR];
}

/*
- (void)viewWillAppear:(BOOL)animated
{
    // Latest:
    //UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style: UIBarButtonItemStyleBordered target:self action:@selector(backPressed)];
    //self.navigationItem.leftBarButtonItem = backButton;
}
 */

- (IBAction)backPressed
{
    //[self dismissViewControllerAnimated:YES completion:nil]; // ios 6

}

- (void)hideKeyBoard
{
    // resign both to be sure
    [self.aorText resignFirstResponder];
    [self.registrarText resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)updatePressed:(id)sender
{
    /**/
    //TabBarController * tabBarController = (TabBarController*)self.tabBarController;
    //this.device = tabBarController.viewController.device;
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    bool update = false;
    if (![self.aorText.text isEqualToString:@""]) {
        [params setObject:self.aorText.text forKey:@"aor"];
        update = true;
    }
    if (![self.registrarText.text isEqualToString:@""]) {
        [params setObject:[NSString stringWithFormat:@"sip:%@", self.registrarText.text] forKey:@"registrar"];
        update = true;
    }

    if (update) {
        //SettingsNavigationController *settingsNavigationController = (SettingsNavigationController*)self.navigationController;
        [self.device updateParams:params];
    }
     /**/
}

- (IBAction)toggleMute:(id)sender
{
    // TODO: mute is no longer applicable to 'Settings' it will just belong to Call view
    /*
    TabBarController * tabBarController = (TabBarController*)self.tabBarController;
    RCConnection * connection = tabBarController.viewController.connection;

    // if we aren't in connected state it doesn't make any sense to mute
    if (connection.state != RCConnectionStateConnected) {
        return;
    }
    
    UISwitch * muteSwitch = sender;
    if (muteSwitch.isOn) {
        connection.muted = true;
    }
    else {
        connection.muted = false;
    }
     */
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
