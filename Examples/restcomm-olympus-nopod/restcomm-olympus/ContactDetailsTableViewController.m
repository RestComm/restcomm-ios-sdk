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

#import "ContactDetailsTableViewController.h"
#import "CallViewController.h"
#import "MessageTableViewController.h"
#import "ContactUpdateTableViewController.h"
#import "Utils.h"

@interface ContactDetailsTableViewController ()

@end

@implementation ContactDetailsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
   
    //show right button (EDIT) for local contacts only
    if (!self.localContact.phoneBookNumber){
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonSelected:)];
    }

    
    self.navigationItem.title = @"Contact Details";
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Edit button selector

- (void) editButtonSelected:(id)sender
{
    [self performSegueWithIdentifier:@"invoke-update" sender:nil];
}


#pragma mark - UITableViewDelegate, UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2 ;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == 0)
    {
        return @"CONTACTS NAME";
    }
    else
    {
        if (self.localContact.phoneBookNumber){
            if (self.localContact.phoneNumbers && [self.localContact.phoneNumbers count] > 1){
                return @"PHONE NUMBERS";
            } else {
                return @"PHONE NUMBER";
            }
        } else {
            return @"RESTCOMM NUMBER OR CLIENT";
        }
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0){
        return 1;
    } else {
        return [self.localContact.phoneNumbers count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"simpleTable";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    if (indexPath.section == 0){
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", self.localContact.firstName, self.localContact.lastName];
    } else {
        cell.textLabel.text = [self.localContact.phoneNumbers objectAtIndex:indexPath.row];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1){
        [self performSegueWithIdentifier:@"invoke-messages" sender:indexPath];
    }
}

#pragma mark - Segue

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString *alias;
    NSString *username;
    NSIndexPath * indexPath = sender;
    alias = [NSString stringWithFormat:@"%@ %@", self.localContact.firstName, self.localContact.lastName];
    
    if ([segue.identifier isEqualToString:@"invoke-messages"]) {
        
        username = [self.localContact.phoneNumbers objectAtIndex:indexPath.row];
        
        MessageTableViewController *messageViewController = [segue destinationViewController];
        messageViewController.device = self.device;
        messageViewController.delegate = self;
        
        messageViewController.parameters = [[NSMutableDictionary alloc] init];
        
        [messageViewController.parameters setObject:alias forKey:@"alias"];
        [messageViewController.parameters setObject:username forKey:@"username"];
    
    } else if ([segue.identifier isEqualToString:@"invoke-update"]){
       
        ContactUpdateTableViewController * contactUpdateViewController = [segue destinationViewController];
        contactUpdateViewController.contactEditType = CONTACT_EDIT_TYPE_MODIFICATION;
        contactUpdateViewController.delegate = self;
       
        username = [self.localContact.phoneNumbers objectAtIndex:0]; //we can edit only contacts we created (one phone number)
        
        contactUpdateViewController.alias = alias;
        contactUpdateViewController.sipUri = username;   
    }
}

#pragma mark - ContactUpdateDelegate method

- (void)contactUpdateViewController:(ContactUpdateTableViewController*)contactUpdateViewController
          didUpdateContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    self.localContact = [Utils getContactForSipUri:sipUri];
    [self.tableView reloadData];
}

#pragma mark - MessageDelegate method

- (void)messageViewController:(MessageTableViewController*)messageViewController
       didAddContactWithAlias:(NSString *)alias sipUri:(NSString*)sipUri
{
    self.localContact = [Utils getContactForSipUri:sipUri];
    [self.tableView reloadData];
}



@end
