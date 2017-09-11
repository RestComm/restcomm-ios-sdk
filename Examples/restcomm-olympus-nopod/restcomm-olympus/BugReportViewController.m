//
//  BugReportViewController.m
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 9/10/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import "BugReportViewController.h"
#import "Utils.h"
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

const int kPickerViewRowHeight = 45;

@interface BugReportViewController () <UIPickerViewDataSource, UIPickerViewDelegate, MFMailComposeViewControllerDelegate>

@property (unsafe_unretained, nonatomic) IBOutlet UILabel *lblIssueType;
@property (unsafe_unretained, nonatomic) IBOutlet UIPickerView *pickerViewIssueType;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *tfAdditionalNote;

@property (unsafe_unretained, nonatomic) IBOutlet UITextField *tfMostRecentPeer;

@property (unsafe_unretained, nonatomic) IBOutlet UILabel *lblDescription;
@property (nonatomic, strong) NSArray *issueTypes;
@end

@implementation BugReportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.issueTypes = @[@"Select issue", @"Dropped midway into call", @"Could not make a call (please provide more details below)",
                        @"Call seems connected but no audio/video", @"Could not send Text Message", @"Cannot connect to Restcomm due to time out",
                        @"Cannot connect to Restcomm due to authentication failure", @"DTMF digits weren\'t detected properly",
                        @"Other (please specify below)"];
    
    
    self.pickerViewIssueType.dataSource = self;
    self.pickerViewIssueType.delegate = self;

    self.pickerViewIssueType.hidden = YES;
    
    
    self.tfAdditionalNote.placeholder = @"Enter additional note of your issue";
    self.tfMostRecentPeer.placeholder = @"Enter most recent Peer";
    
    //set most recent peer (if any)
    self.tfMostRecentPeer.text = [Utils getLastPeer];
    
    //set gesture recognizer for lblIssueType
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(lblIssueTypeTapped:)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    self.lblIssueType.userInteractionEnabled = YES;
    [self.lblIssueType addGestureRecognizer:tapGestureRecognizer];
    
    [self.view bringSubviewToFront: self.pickerViewIssueType];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UIPickerViewDataSource methods

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.issueTypes.count;
}

#pragma mark UIPickerViewDelegate methods

- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return self.issueTypes[row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component{
    self.lblIssueType.hidden = NO;
    self.tfAdditionalNote.hidden = NO;
    self.tfMostRecentPeer.hidden = NO;
    self.lblDescription.hidden = NO;

    self.lblIssueType.text = self.issueTypes[row];
    self.pickerViewIssueType.hidden = YES;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel* pickerLabel = (UILabel*)view;
    
    if (!pickerLabel)
    {
        pickerLabel = [[UILabel alloc] init];
        pickerLabel.font = [UIFont fontWithName:@"SourceSansPro-Semibold" size:15];
        pickerLabel.textAlignment = NSTextAlignmentCenter;
    }
    //some of the settings types are to big, we wan to show them
    //by breaking into rows
    [pickerLabel setLineBreakMode:NSLineBreakByWordWrapping];
    pickerLabel.numberOfLines = 0;
    [pickerLabel sizeToFit];
    
    [pickerLabel setText:[self.issueTypes objectAtIndex:row]];
    
    return pickerLabel;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component{
    return kPickerViewRowHeight;
}

#pragma mark - lblIssueType tap method

- (void)lblIssueTypeTapped:(UITapGestureRecognizer *)tapGesture {
    self.pickerViewIssueType.hidden = NO;
    self.tfAdditionalNote.hidden = YES;
    self.tfMostRecentPeer.hidden = YES;
    self.lblDescription.hidden = YES;
    self.lblIssueType.hidden = YES;
}

#pragma mark - NavigationBar buttons methods

- (IBAction)onSendTap:(id)sender {
    //issue type must be selected
    if ([self.lblIssueType.text isEqualToString:@"Select issue"]){
        [Utils shakeView:self.lblIssueType];
        return;
    }
    NSString *trimmedAdditional = [self.tfAdditionalNote.text stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
    //if user selects the last option (other) we need to make sure that additional text is added
    if ([self.lblIssueType.text isEqualToString:@"Other (please specify below)"] && trimmedAdditional.length == 0){
        [Utils shakeView:self.self.tfAdditionalNote];
        return;
    }
    
    //check domain
    NSString *domain = [Utils sipRegistrar];
    
    if (![domain containsString:@".restcomm.com"]) {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Warning"
                                     message:@"Bug reports are only applicable to Restcomm Cloud domain."
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    [self showMailComposeViewController];
}

- (IBAction)onCancelTap:(id)sender {
     [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Send email

- (void)showMailComposeViewController {
    
    
    NSString * version = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
    NSString * build = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    
    NSTimeZone* timeZone = [NSTimeZone localTimeZone];
    NSString* timeZoneName = [timeZone localizedName:NSTimeZoneNameStyleStandard locale:[NSLocale currentLocale]];
   

    NSString *emailTitle = @"[restcomm-android-sdk] User bug report for Olympus";
    NSString *messageBody = @"Client: ios-sdk \n";

    messageBody = [NSString stringWithFormat:@"%@Issue: %@ \n", messageBody, self.lblIssueType.text];
    messageBody = [NSString stringWithFormat:@"%@Additional Note: %@ \n", messageBody, self.tfAdditionalNote.text];
    messageBody = [NSString stringWithFormat:@"%@Peer: %@ \n", messageBody, self.tfMostRecentPeer.text];
    messageBody = [NSString stringWithFormat:@"%@Domain: %@ \n", messageBody,[Utils sipRegistrar]];
    messageBody = [NSString stringWithFormat:@"%@Timezone: %@ \n", messageBody, timeZoneName];
    messageBody = [NSString stringWithFormat:@"%@Olympus Version: %@ \n", messageBody, version];
    messageBody = [NSString stringWithFormat:@"%@Olympus Build: %@ \n", messageBody, build];

    NSArray *toRecipents = [NSArray arrayWithObject:@"antonis.tsakiridis@telestax.com"];
    
    Class mailClass = (NSClassFromString(@"MFMailComposeViewController"));
    if ([mailClass canSendMail]){
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        mc.mailComposeDelegate = self;
        [mc setSubject:emailTitle];
        [mc setMessageBody:messageBody isHTML:NO];
        [mc setToRecipients:toRecipents];
        
        [self presentViewController:mc animated:YES completion:NULL];
    } else {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Warning"
                                     message:@"Sending emails is not supported on this device."
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:nil];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];

    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    //we will just log the result
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail sent failure: %@", [error localizedDescription]);
            break;
        default:
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}


@end
