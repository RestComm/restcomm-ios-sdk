//
//  KeypadViewController.m
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 10/1/15.
//  Copyright © 2015 TeleStax. All rights reserved.
//

#import "KeypadViewController.h"
#include <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>   // sounds

@interface KeypadViewController ()
@property SystemSoundID systemSound;
@property AVAudioPlayer * audioPlayer;
@end

@implementation KeypadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onePressed:(id)sender {
    [self playSound:@"dtmf1.wav"];
    [self.connection sendDigits:@"1"];
}

- (IBAction)twoPressed:(id)sender {
    [self playSound:@"dtmf2.wav"];
    [self.connection sendDigits:@"2"];
}

- (IBAction)threePressed:(id)sender {
    [self playSound:@"dtmf3.wav"];
    [self.connection sendDigits:@"3"];
}

- (IBAction)fourPressed:(id)sender {
    [self playSound:@"dtmf4.wav"];
    [self.connection sendDigits:@"4"];
}

- (IBAction)fivePressed:(id)sender {
    [self playSound:@"dtmf5.wav"];
    [self.connection sendDigits:@"5"];
}

- (IBAction)sixPressed:(id)sender {
    [self playSound:@"dtmf6.wav"];
    [self.connection sendDigits:@"6"];
}

- (IBAction)sevenPressed:(id)sender {
    [self playSound:@"dtmf7.wav"];
    [self.connection sendDigits:@"7"];
}

- (IBAction)eightPressed:(id)sender {
    [self playSound:@"dtmf8.wav"];
    [self.connection sendDigits:@"8"];
}

- (IBAction)ninePressed:(id)sender {
    [self playSound:@"dtmf9.wav"];
    [self.connection sendDigits:@"9"];
}

- (IBAction)zeroPressed:(id)sender {
    [self playSound:@"dtmf0.wav"];
    [self.connection sendDigits:@"0"];
}

- (IBAction)starPressed:(id)sender {
    [self playSound:@"star.wav"];
    [self.connection sendDigits:@"*"];
}

- (IBAction)hashPressed:(id)sender {
    [self playSound:@"pound.wav"];
    [self.connection sendDigits:@"#"];
}

- (IBAction)donePressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// we are initializing and playing (not the best way, but will suffice for this usage)
- (void) playSound:(NSString*)filename
{
    // we are assuming the extension will always be the last 3 letters of the filename
    NSString * file = [[NSBundle mainBundle] pathForResource:[filename substringToIndex:[filename length] - 3 - 1]
                                                      ofType:[filename substringFromIndex:[filename length] - 3]];
    if (file != nil) {
        NSError *error;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:file] error:&error];
        if (!self.audioPlayer) {
            NSLog(@"Error: %@", [error description]);
            return;
        }
    }
    [self.audioPlayer play];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
