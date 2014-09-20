//
//  ViewController.m
//  test-ios-sip-sofia
//
//  Created by Antonis Tsakiridis on 9/7/14.
//  Copyright (c) 2014 TeleStax. All rights reserved.
//

#import "ViewController.h"

//#include "sofia-ua-wrapper.h"
#include "sofsip_cli.h"
#include <unistd.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *sipMessageText;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // initialize sofia
    int pipefd[2];
    
    if (pipe(pipefd) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }
    
    self.sofia_input_fd = pipefd[0];
    self.sofia_output_fd = pipefd[1];

    // sofia has its own event loop, so we need to call it asynchronously. The big question thought,
    // is how do we communicate with it? We need a way to send messages to it to convey the actions
    // we want it to take depending on the user's input in the iphone
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //sofia_loop([self.sipMessageText.text UTF8String]);
        sofsip_loop(0, NULL, self.sofia_input_fd);
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sendPressed:(id)sender
{
    int rc = write(self.sofia_output_fd, [self.sipMessageText.text UTF8String], self.sipMessageText.text.length);
    /*
    if (rc == -1) {
        perror("Error_ ");
    }
    else {
        printf("Successful write");
    }
     */
}

@end
