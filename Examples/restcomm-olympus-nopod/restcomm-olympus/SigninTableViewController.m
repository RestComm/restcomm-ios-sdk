//
//  SigninTableViewController.m
//  restcomm-olympus
//
//  Created by Antonis Tsakiridis on 2/19/16.
//  Copyright © 2016 TeleStax. All rights reserved.
//

#import "SigninTableViewController.h"
#import "MainTableViewController.h"
#import "Utils.h"
#import "RCUtilities.h"
#import "AppDelegate.h"

@interface SigninTableViewController ()
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *usernameText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *passwordText;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *domainText;

@end

@implementation SigninTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (![Utils isFirstTime]) {
        // Open message view if not already opened
        
        // initialize RCDevice
        [self registerRCDevice];
     
        // register push
        [self registerForPush];
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
        MainTableViewController *mainViewController = [storyboard instantiateViewControllerWithIdentifier:@"contacts-controller"];
        [self.navigationController pushViewController:mainViewController animated:NO];
    }
    self.usernameText.text = [Utils sipIdentification];
    self.passwordText.text = [Utils sipPassword];
    self.domainText.text = [Utils sipRegistrar];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([self.usernameText.text isEqualToString:@""] || [self.domainText.text isEqualToString:@""]) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Validation Error"
                                     message:@"Username and Domain fields are mandatory"
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return NO;
    }
    
    //if ([self.usernameText.text containsString:@"sip:"] || [self.usernameText.text containsString:@"@"]) {
    if ([RCUtilities string:self.usernameText.text containsString:@"sip:"] || [RCUtilities string:self.usernameText.text containsString:@"@"]) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Validation Error"
                                     message:@"Please avoid using a SIP URI for Username. Use a plain username instead, like 'bob' or 'alice'"
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return NO;
    }
 
    return YES;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [Utils updateSipIdentification:_usernameText.text];
    [Utils updateSipPassword:_passwordText.text];
    [Utils updateSipRegistrar:_domainText.text];
    [Utils updateIsFirstTime:NO];
    
    // initialize RCDEvice
    [self registerRCDevice];
   
    // register push
    [self registerForPush];
}

- (RCDevice *)registerRCDevice{
    //get device instance from App delegate
    AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    return [appDelegate registerRCDevice];
}

- (void)registerForPush{
    //before setting the push token, we need to check is push enabled (server can handle it)
    if ([Utils isServerEnabledForPushNotifications]){
        NSLog(@"Start registering for push on server");
        NSString *deviceToken = [Utils pushToken];
        NSString *pushAccount = [Utils pushAccount];
        
        if (deviceToken && pushAccount){
            AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
            RCDevice *rcDevice = [appDelegate registerRCDevice];
            if (rcDevice){
                //get certificate strings
                NSString *pushCertificatesPathPublic = [[NSBundle mainBundle] pathForResource:@"certificate_key_push" ofType:@"pem"];
                NSString *pushCertificatesPathPrivate = [[NSBundle mainBundle] pathForResource:@"rsa_private_key_push" ofType:@"pem"];
              
                
                NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                            kFriendlyName, RCPushFriendlyNameKey,
                                            [Utils pushAccount], RCRestcommAccountEmailKey,
                                            [Utils pushPassword], RCRestcommAccountPasswordKey,
                                            [Utils pushDomain], RCPushDomainKey,
                                            deviceToken, RCPushTokenKey,
                                            pushCertificatesPathPublic, RCPushCertificatesPathPublicKey,
                                            pushCertificatesPathPrivate, RCPushCertificatesPathPrivateKey,
                                            [NSNumber numberWithBool:[Utils isSandbox]], RCPushIsSandbox, nil];
                
                [rcDevice registerPushToken:dic delegate:self];
            } else {
                NSLog(@"Device Voip push token not found, or RCDevice not initialized");
            }
        }else {
            NSLog(@"Device token or restcomm push account are not initialized");
        }
    }
    
}

-(void)registeredForPush:(NSError *)error{
    NSLog(@"%@", error?error.description:@"App registered for push");
}


@end
