//
//  ViewController.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#include <unistd.h>

#import "ViewController.h"
#import "SofiaSIP.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.sofiaSIP = [[SofiaSIP alloc] init];
    [self.sofiaSIP initialize];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendPressed:(id)sender
{
    [self.sofiaSIP sendMessage:self.sipMessageText.text to:@"sip:alice@192.168.2.30:5080"];
    //[self.sofiaSIP generic:self.sipMessageText.text];
    self.sipMessageText.text = @"";
}

@end
