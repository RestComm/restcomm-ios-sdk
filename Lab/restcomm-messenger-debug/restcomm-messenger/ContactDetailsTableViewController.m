//
//  ContactDetailsTableViewController.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "ContactDetailsTableViewController.h"
#import "CallViewController.h"
#import "MessageViewController.h"
#import "ContactUpdateTableViewController.h"

@interface ContactDetailsTableViewController ()
@property (weak, nonatomic) IBOutlet UILabel *sipUriLbl;
@property (weak, nonatomic) IBOutlet UILabel *aliaslLbl;
@property (weak, nonatomic) IBOutlet UIImageView *videoCallImage;
@end

@implementation ContactDetailsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    self.videoCallImage.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    // add edit button manually, to get the actions (from storyboard default actions for edit don't work)
    //self.navigationItem.rightBarButtonItem = [self editButtonItem];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonSelected:)];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) editButtonSelected:(id)sender
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    // important: we are retrieving the navigation controller that hosts the contact update table view controller (due to the issue we had on the buttons showing wrong)
    UINavigationController *contactUpdateNavigationController = [storyboard instantiateViewControllerWithIdentifier:@"contact-update-nav-controller"];
    ContactUpdateTableViewController * contactUpdateViewController =  [contactUpdateNavigationController.viewControllers objectAtIndex:0];
    contactUpdateViewController.contactEditType = CONTACT_EDIT_TYPE_MODIFICATION;
    contactUpdateViewController.alias = self.alias;
    contactUpdateViewController.sipUri = self.sipUri;
    contactUpdateViewController.delegate = self;
    
    [self presentViewController:contactUpdateNavigationController animated:YES completion:nil];
    /*
    if (self.tableView.editing) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonSelected:)];
        [self.tableView setEditing:NO animated:YES];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editButtonSelected:)];
        [self.tableView setEditing:YES animated:YES];
    }
     */
    
}

- (void)audioCallPressed
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    
    // setup call view controller
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:self.alias forKey:@"alias"];
    [callViewController.parameters setObject:self.sipUri forKey:@"username"];
    [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:@"video-enabled"];
    
    [self presentViewController:callViewController animated:YES completion:nil];
}


- (void)videoCallPressed
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    CallViewController *callViewController = [storyboard instantiateViewControllerWithIdentifier:@"call-controller"];
    
    // setup call view controller
    callViewController.delegate = self;
    callViewController.device = self.device;
    callViewController.parameters = [[NSMutableDictionary alloc] init];
    [callViewController.parameters setObject:@"make-call" forKey:@"invoke-view-type"];
    [callViewController.parameters setObject:self.alias forKey:@"alias"];
    [callViewController.parameters setObject:self.sipUri forKey:@"username"];
    [callViewController.parameters setObject:[NSNumber numberWithBool:YES] forKey:@"video-enabled"];
    
    [self presentViewController:callViewController animated:YES completion:nil];
}

- (void)messagePressed
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"] bundle:nil];
    MessageViewController *messageViewController = [storyboard instantiateViewControllerWithIdentifier:@"message-controller"];

    messageViewController.device = self.device;
    messageViewController.parameters = [[NSMutableDictionary alloc] init];
    [messageViewController.parameters setObject:self.alias forKey:@"alias"];
    [messageViewController.parameters setObject:self.sipUri forKey:@"username"];
    
    [self.navigationController pushViewController:messageViewController animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.sipUriLbl.text = self.sipUri;
    self.aliaslLbl.text = self.alias;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
/*
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = NSLocalizedString(self.alias, self.alias);
            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}
 */

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self videoCallPressed];
        }
        if (indexPath.row == 1) {
            [self audioCallPressed];
        }
        if (indexPath.row == 2) {
            [self messagePressed];
        }
    }
}

// UITableView asks us if each of the rows are editable
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // our rows aren't editable
    return NO;
}

- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    self.sipUri = sipUri;
    self.sipUriLbl.text = sipUri;
    self.alias = alias;
    self.aliaslLbl.text = alias;
    
    // notify main screen that we updated, so that contact table is updated as well
    [self.delegate contactDetailsViewController:self
                      didUpdateContactWithAlias:alias sipUri:sipUri];
}


/*
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#warning Incomplete method implementation.
    // Return the number of rows in the section.
    return 0;
}
 */

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
