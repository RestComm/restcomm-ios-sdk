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
        self.sipUriTxt.userInteractionEnabled = NO;
    }
    else {
        [self.aliasTxt becomeFirstResponder];
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
        [Utils updateContactWithSipUri:self.sipUriTxt.text alias:self.aliasTxt.text];
        
        [self.delegate contactUpdateViewController:self didUpdateContactWithAlias:self.aliasTxt.text
                                            sipUri:self.sipUriTxt.text];
    }
    else {
        if (![self.aliasTxt.text isEqualToString:@""] && ![self.sipUriTxt.text isEqualToString:@""]) {
            LocalContact *localContact = [[LocalContact alloc] initWithFirstName:self.aliasTxt.text lastName:@"" andPhoneNumbers:@[self.sipUriTxt.text]];
            [Utils addContact:localContact];
            
            [self.delegate contactUpdateViewController:self didUpdateContactWithAlias:self.aliasTxt.text
                                                sipUri:self.sipUriTxt.text];
        }
        else {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"Invalid Input"
                                         message:@"Please fill in Username and SIP URI fields"
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction
                                       actionWithTitle:@"OK"
                                       style:UIAlertActionStyleDefault
                                       handler:nil];
            [alert addAction:okAction];


            [self presentViewController:alert animated:YES completion:nil];
            return;
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
