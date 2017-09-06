//
//  PhoneNumbersViewController.m
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 9/6/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import "PhoneNumbersViewController.h"

@interface PhoneNumbersViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (unsafe_unretained, nonatomic) IBOutlet UITableView *tableView;
@end

@implementation PhoneNumbersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDelegate, UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.localContact.phoneNumbers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"simpleTable";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.textLabel.text = [self.localContact.phoneNumbers objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.phoneNumbersDelegate onPhoneNumberTap:[NSString stringWithFormat:@"%@ %@", self.localContact.firstName, self.localContact.lastName]  andSipUri:self.localContact.phoneNumbers[[indexPath row]]];
}

@end
