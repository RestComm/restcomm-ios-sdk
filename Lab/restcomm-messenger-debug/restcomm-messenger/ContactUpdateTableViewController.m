//
//  ContactUpdateTableViewController.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/17/15.
//  Copyright (c) 2015 TeleStax. All rights reserved.
//

#import "ContactUpdateTableViewController.h"
#import "Utils.h"

@interface ContactUpdateTableViewController ()
@property (weak, nonatomic) IBOutlet UITextField *aliasTxt;
@property (weak, nonatomic) IBOutlet UITextField *sipUriTxt;

@end

@implementation ContactUpdateTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    
    if (self.contactEditType == CONTACT_EDIT_TYPE_MODIFICATION) {
        self.navigationItem.title = @"Edit Contact";
    }
    else {
        self.navigationItem.title = @"Add Contact";
    }
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.contactEditType == CONTACT_EDIT_TYPE_MODIFICATION) {
        self.aliasTxt.text = self.alias;
        self.sipUriTxt.text = self.sipUri;
        self.aliasTxt.userInteractionEnabled = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)cancelPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)donePressed:(id)sender
{
    if (self.contactEditType == CONTACT_EDIT_TYPE_MODIFICATION) {
        [Utils updateContactWithAlias:self.aliasTxt.text sipUri:self.sipUriTxt.text];
        [self.delegate contactUpdateViewController:self didUpdateContactWithAlias:self.aliasTxt.text
                                            sipUri:self.sipUriTxt.text];
    }
    else {
        if (![self.aliasTxt.text isEqualToString:@""] && ![self.sipUriTxt.text isEqualToString:@""]) {
            [Utils addContact:[NSArray arrayWithObjects:self.aliasTxt.text, self.sipUriTxt.text, nil]];
            [self.delegate contactUpdateViewController:self didUpdateContactWithAlias:self.aliasTxt.text
                                                sipUri:self.sipUriTxt.text];
        }
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

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
