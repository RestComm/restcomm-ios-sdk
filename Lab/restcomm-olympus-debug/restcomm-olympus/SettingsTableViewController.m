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

#import "SettingsTableViewController.h"
#import "SipSettingsTableViewController.h"

@implementation SettingsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //[[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0]];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0];
    self.navigationItem.title = @"Settings";
    //[self.navigationItem.backBarButtonItem setTintColor:[UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0]];
    //[self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:235.0/255.0 green:91.0/255.0 blue:41.0/255.0 alpha:255.0/255.0]];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"invoke-sip-settings"]) {
        SipSettingsTableViewController * sipSettingsTableViewController = [segue destinationViewController];
        sipSettingsTableViewController.device = self.device;
    }
    /*
    if ([segue.identifier isEqualToString:@"invoke-message-controller"]) {
        MessageViewController *callViewController = [segue destinationViewController];
        callViewController.device = self.device;
        callViewController.parameters = [[NSMutableDictionary alloc] init];
        [callViewController.parameters setObject:self.sipUriText.text forKey:@"username"];
    }
     */
}
@end
