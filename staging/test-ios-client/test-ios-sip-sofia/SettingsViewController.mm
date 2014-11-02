//
//  SettingsViewController.m
//  test-ios-client
//
//  Created by Antonis Tsakiridis on 10/11/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import "SettingsViewController.h"
#import "TabBarController.h"

@interface SettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *aorText;
@property (weak, nonatomic) IBOutlet UITextField *registrarText;

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

#ifdef DEBUG
    // set some defaults when in debug to avoid typing
    self.aorText.text = @"sip:bob@telestax.com";
    self.registrarText.text = @"23.23.228.238";
#endif
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
    TabBarController * tabBarController = (TabBarController*)self.tabBarController;
    RCDevice * device = tabBarController.device;
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    bool update = false;
    if (![self.aorText.text isEqualToString:@""]) {
        [params setObject:self.aorText.text forKey:@"aor"];
        update = true;
    }
    if (![self.registrarText.text isEqualToString:@""]) {
        [params setObject:[NSString stringWithFormat:@"sip:%@:5080", self.registrarText.text] forKey:@"registrar"];
        //[params setObject:self.registrarText.text forKey:@"registrar"];
        //[params setObject:[NSString stringWithFormat:@"sip:%@@%@:5080", @"%@", self.registrarText.text] forKey:@"uas-uri-template"];
        update = true;
    }

    if (update) {
        [device updateParams:params];
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
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
