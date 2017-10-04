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
        // initialize RCDEvice
        RCDevice *rcDevice = [self registerRCDevice];
        // register push
        
        NSString *userName = [NSString stringWithFormat:@"%@@telestax.com", [Utils sipIdentification]];
        
        [self registerForPushWithAccount:userName withRCDevice:rcDevice password:[Utils sipPassword] andEmail:userName];
        
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

/*
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
#warning Incomplete implementation, return the number of sections
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
#warning Incomplete implementation, return the number of rows
    return 0;
}
*/

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([self.usernameText.text isEqualToString:@""] || [self.domainText.text isEqualToString:@""]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Validation Error"
                                                        message:@"Username and Domain fields are mandatory"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
    
    //if ([self.usernameText.text containsString:@"sip:"] || [self.usernameText.text containsString:@"@"]) {
    if ([RCUtilities string:self.usernameText.text containsString:@"sip:"] || [RCUtilities string:self.usernameText.text containsString:@"@"]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Validation Error"
                                                        message:@"Please avoid using a SIP URI for Username. Use a plain username instead, like 'bob' or 'alice'"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
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
    RCDevice *rcDevice = [self registerRCDevice];
    // register push
    NSString *userName = [NSString stringWithFormat:@"%@@telestax.com", _usernameText.text];
    [self registerForPushWithAccount:userName withRCDevice:rcDevice password:[Utils sipPassword] andEmail:userName];
}

- (RCDevice *)registerRCDevice{
    //get device instance from App delegate
    AppDelegate *appDelegate = ((AppDelegate *)[UIApplication sharedApplication].delegate);
    return [appDelegate registerRCDevice];
}

- (void)registerForPushWithAccount:(NSString *)account withRCDevice:(RCDevice *)rcDevice password:(NSString *)password andEmail:(NSString *)email{
    //get token from user defaults
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    NSString *deviceToken = [appDefaults objectForKey:@"deviceToken"];
    if (deviceToken && rcDevice){
        //get certificate strings
        NSString *pushCertificatesPathPublic = [[NSBundle mainBundle] pathForResource:@"certificate_key_push" ofType:@"pem"];
        NSString *pushCertificatesPathPrivate = [[NSBundle mainBundle] pathForResource:@"rsa_private_key_push" ofType:@"pem"];
        
      

        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                    @"Olympus", @"friendly-name",
                                    account, @"username",
                                    password, @"password",
                                    email, @"rescomm-account-email",
                                    deviceToken, @"token",
                                    pushCertificatesPathPublic, @"push-certificate-public-path",
                                    pushCertificatesPathPrivate, @"push-certificate-private-path",
                                    [NSNumber numberWithBool:YES], @"is-sandbox", nil];
        
        [rcDevice registerPushToken:dic];
        
    } else {
        NSLog(@"Device Voip push token not found, or RCDevice not initialized");
    }
}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
