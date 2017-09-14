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
        self.aliasTxt.userInteractionEnabled = NO;

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
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)donePressed:(id)sender
{
    if (self.contactEditType == CONTACT_EDIT_TYPE_MODIFICATION) {
        [Utils updateContactWithSipUri:self.sipUriTxt.text forAlias:self.aliasTxt.text];
        
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

    [self.navigationController popViewControllerAnimated:YES];
}


@end
