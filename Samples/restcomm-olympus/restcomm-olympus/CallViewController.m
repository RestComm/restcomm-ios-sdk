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

#import "CallViewController.h"
#import "RestCommClient.h"
//#import "Utilities.h"
#import "KeypadViewController.h"

@interface CallViewController ()
@property (weak, nonatomic) IBOutlet UIButton *hangupButton;
@property (weak, nonatomic) IBOutlet UIButton *videoButton;
@property (weak, nonatomic) IBOutlet UIButton *audioButton;
@property (weak, nonatomic) IBOutlet UIButton *muteVideoButton;
@property (weak, nonatomic) IBOutlet UIButton *keypadButton;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIButton *muteAudioButton;
// who we are calling/get called from
@property (weak, nonatomic) IBOutlet UILabel *callLabel;
// signaling/media status to inform the user how call setup goes (like Android toasts)
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (unsafe_unretained, nonatomic) IBOutlet UIImageView *speakerImage;

@property ARDVideoCallView *videoCallView;
@property RTCVideoTrack *remoteVideoTrack;
@property RTCVideoTrack *localVideoTrack;
@property BOOL isAudioMuted, isVideoMuted, isSpeakerEnabled;
@property BOOL pendingError;
@property NSTimer *durationTimer;
@property int secondsElapsed;
@property BOOL isVideoCall;
@end

@implementation CallViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.pendingError = NO;
    self.isVideoMuted = NO;
    self.isAudioMuted = NO;
    self.isSpeakerEnabled = NO;
    
    self.videoCallView = [[ARDVideoCallView alloc] initWithFrame:self.view.frame];
    self.videoCallView.hidden = YES;
    self.durationLabel.hidden = YES;
    
    [self.view insertSubview:self.videoCallView belowSubview:self.hangupButton];
    
    // add gesture recognizer to the main view for the toggle speaker action
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc]
                                             initWithTarget:self action:@selector(tapGestureHandler:)];
    
    // Specify that the gesture must be a single tap
    tapRecognizer.numberOfTapsRequired = 2;
    
    // Add the tap gesture recognizer to the view
    [self.view addGestureRecognizer:tapRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.isBeingPresented) {
        if (!self.connection || self.connection.state != RCConnectionStateConnected) {
            self.muteAudioButton.hidden = YES;
            self.muteVideoButton.hidden = YES;
            self.keypadButton.hidden = YES;
        }
        
        if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"make-call"]) {
            self.videoButton.hidden = YES;
            self.audioButton.hidden = YES;
        }
        if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"receive-call"]) {
            self.videoButton.hidden = NO;
            self.audioButton.hidden = NO;
        }
        
        // for the duration of the call don't allow the screen to sleep (we will remove this when backgrounding is implemented)
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.isBeingDismissed) {
        // we are leaving the call, allow the screen to sleep
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.isBeingPresented) {
        if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"make-call"]) {
            // call the other party
            if (self.connection) {
                NSLog(@"Connection already ongoing");
                return;
            }
            
            if ([[self.parameters objectForKey:@"video-enabled"] boolValue] == YES) {
                self.isVideoCall = YES;
            }
            else {
                self.isVideoCall = NO;
            }
            
            //NSString *username = [Utilities usernameFromUri:[self.parameters objectForKey:@"username"]];
            self.callLabel.text = [NSString stringWithFormat:@"Calling %@", [self.parameters objectForKey:@"username"]];
            self.statusLabel.text = @"Initiating Call...";
            // *** SIP custom headers: uncomment this to use SIP custom headers
            //[self.parameters setObject:[NSDictionary dictionaryWithObjectsAndKeys:@"Value1", @"Key1", @"Value2", @"Key2", nil]
            //                    forKey:@"sip-headers"];
            self.connection = [self.device connect:self.parameters delegate:self];
            if (self.connection == nil) {
                self.pendingError = YES;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"RCDevice Error"
                                                                message:@"Not connected"
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        }
        if ([[self.parameters valueForKey:@"invoke-view-type"] isEqualToString:@"receive-call"]) {
            //NSString *username = [Utilities usernameFromUri:[self.parameters objectForKey:@"username"]];
            self.callLabel.text = [NSString stringWithFormat:@"Call from %@", [self.parameters objectForKey:@"username"]];
            self.statusLabel.text = @"Call received";
        }
    }
}

- (IBAction)tapGestureHandler:(UITapGestureRecognizer *)recognizer {
    // Get the location of the gesture
    //CGPoint location = [recognizer locationInView:self.view];
    
    // if we aren't in connected state it doesn't make any sense to mute
    if (self.connection.state != RCConnectionStateConnected) {
        return;
    }
    
    if (!self.isSpeakerEnabled) {
        self.speakerImage.hidden = NO;
        self.connection.speaker = true;
        self.isSpeakerEnabled = YES;
    }
    else {
        self.speakerImage.hidden = YES;
        self.connection.speaker = false;
        self.isSpeakerEnabled = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)answerPressed:(id)sender
{
    self.isVideoCall = NO;
    [self answer:NO];
}

- (IBAction)answerVideoPressed:(id)sender
{
    self.isVideoCall = YES;
    [self answer:YES];
}

- (void)answer:(BOOL)allowVideo
{
    if (self.pendingIncomingConnection) {
        // hide video/audio buttons
        self.videoButton.hidden = YES;
        self.audioButton.hidden = YES;

        self.statusLabel.text = @"Answering Call...";
        if (allowVideo) {
            [self.pendingIncomingConnection accept:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                                               forKey:@"video-enabled"]];
        }
        else {
            [self.pendingIncomingConnection accept:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                                               forKey:@"video-enabled"]];
        }
        self.connection = self.pendingIncomingConnection;
        self.pendingIncomingConnection = nil;
    }
}

- (IBAction)hangUpPressed:(id)sender
{
    NSLog(@"[CallViewController hangUpPressed]");
    if (self.pendingIncomingConnection) {
        // incomind ringing
        self.statusLabel.text = @"Rejecting Call...";
        [self.pendingIncomingConnection reject];
        //[self.pendingIncomingConnection ignore];
        self.pendingIncomingConnection = nil;
    }
    else {
        if (self.connection) {
            self.statusLabel.text = @"Disconnecting Call...";
            [self stopVideoRendering];
            [self.connection disconnect];
            self.connection = nil;
            self.pendingIncomingConnection = nil;
        }
        else {
            NSLog(@"Error: not connected/connecting/pending");
        }
    }
    NSLog(@"[CallViewController hangUpPressed], dismissing");
    [self.presentingViewController dismissViewControllerAnimated:YES
                                                      completion:nil];
}

- (void)stopVideoRendering
{
    NSLog(@"[CallViewController stopVideoRendering]");
    if (self.remoteVideoTrack) {
        [self.remoteVideoTrack removeRenderer:self.videoCallView.remoteVideoView];
        self.remoteVideoTrack = nil;
        [self.videoCallView.remoteVideoView renderFrame:nil];
    }
    if (self.localVideoTrack) {
        [self.localVideoTrack removeRenderer:self.videoCallView.localVideoView];
        self.localVideoTrack = nil;
        [self.videoCallView.localVideoView renderFrame:nil];
    }
}

// ---------- Delegate methods for RC Connection
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error
{
    NSLog(@"connection didFailWithError");
    self.pendingError = YES;
    self.connection = nil;
    self.pendingIncomingConnection = nil;
    [self stopVideoRendering];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"RCConnection Error"
                                                    message:[[error userInfo] objectForKey:NSLocalizedDescriptionKey]
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

// optional
// 'ringing' for outgoing connections
- (void)connectionDidStartConnecting:(RCConnection*)connection
{
    NSLog(@"connectionDidStartConnecting");
    self.statusLabel.text = @"Did start connecting";
}

- (void)connectionDidConnect:(RCConnection*)connection
{
    NSLog(@"connectionDidConnect");
    self.statusLabel.text = @"Connected";
    
    // show mute video/audio/keypad buttons
    self.muteAudioButton.hidden = NO;
    self.muteVideoButton.hidden = NO;
    self.keypadButton.hidden = NO;

    self.durationLabel.hidden = NO;
    [self timerAction];
}

- (void)connectionDidCancel:(RCConnection*)connection
{
    NSLog(@"connectionDidCancel");
    
    if (self.pendingIncomingConnection) {
        self.statusLabel.text = @"Remote party Cancelled";
        self.pendingIncomingConnection = nil;
        self.connection = nil;
        [self stopVideoRendering];

        [self.presentingViewController dismissViewControllerAnimated:YES
                                                          completion:nil];
    }
}

- (void)connectionDidDisconnect:(RCConnection*)connection
{
    NSLog(@"connectionDidDisconnect");
    self.statusLabel.text = @"Disconnected";
    self.connection = nil;
    self.pendingIncomingConnection = nil;
    [self stopVideoRendering];

    // hide mute video/audio buttons
    self.muteAudioButton.hidden = YES;
    self.muteVideoButton.hidden = YES;

    if (!self.pendingError) {
        // if we have presented the digits view controller need to dismiss both
        if (self.presentedViewController) {
            // change the value of invoke-view-type cause if we don't a new call will be made due to viewDidAppear
            [self.parameters setValue:@"return-from-keypad" forKey:@"invoke-view-type"];
            [self.presentedViewController dismissViewControllerAnimated:YES completion:^{
                [self.presentingViewController dismissViewControllerAnimated:YES
                                                                  completion:nil];
            }];
        }
        else {
            [self.presentingViewController dismissViewControllerAnimated:YES
                                                              completion:nil];
        }
    }
    else {
        // if we have presented the digits view controller need to dismiss both
        if (self.presentedViewController) {
            // change the value of invoke-view-type cause if we don't a new call will be made due to viewDidAppear
            [self.parameters setValue:@"return-from-keypad" forKey:@"invoke-view-type"];

            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }
    }
    
    if (self.durationTimer && [self.durationTimer isValid]) {
        [self.durationTimer invalidate];
    }
}

- (void)connectionDidGetDeclined:(RCConnection*)connection
{
    NSLog(@"connectionDidGetDeclined");
    self.statusLabel.text = @"Got Declined";

    self.connection = nil;
    self.pendingIncomingConnection = nil;
    [self stopVideoRendering];

    [self.presentingViewController dismissViewControllerAnimated:YES
                                                      completion:nil];
}

- (void)connection:(RCConnection *)connection didReceiveLocalVideo:(RTCVideoTrack *)localVideoTrack
{
    NSLog(@"[connection:didReceiveLocalVideo:]");
    if (self.isVideoCall && !self.localVideoTrack) {
        self.statusLabel.text = @"Received local video";
        self.localVideoTrack = localVideoTrack;
        [self.localVideoTrack addRenderer:self.videoCallView.localVideoView];
    }
}

- (void)connection:(RCConnection *)connection didReceiveRemoteVideo:(RTCVideoTrack *)remoteVideoTrack
{
    if (self.isVideoCall && !self.remoteVideoTrack) {
        self.statusLabel.text = @"Received remote video";
        self.remoteVideoTrack = remoteVideoTrack;
        [self.remoteVideoTrack addRenderer:self.videoCallView.remoteVideoView];
        self.videoCallView.hidden = NO;
    }
}

- (IBAction)toggleMuteAudio:(id)sender
{
    // if we aren't in connected state it doesn't make any sense to mute
    if (self.connection.state != RCConnectionStateConnected) {
        return;
    }
    
    if (!self.isAudioMuted) {
        self.connection.muted = true;
        self.isAudioMuted = YES;
        [self.muteAudioButton setImage:[UIImage imageNamed:@"audio-muted-50x50.png"] forState:UIControlStateNormal];
    }
    else {
        self.connection.muted = false;
        self.isAudioMuted = NO;
        [self.muteAudioButton setImage:[UIImage imageNamed:@"audio-active-50x50.png"] forState:UIControlStateNormal];
    }
}

- (IBAction)toggleMuteVideo:(id)sender
{
    // if we aren't in connected state it doesn't make any sense to mute
    if (self.connection.state != RCConnectionStateConnected) {
        return;
    }
    
    if (!self.isVideoMuted) {
        self.connection.videoMuted = true;
        self.isVideoMuted = YES;
        [self.muteVideoButton setImage:[UIImage imageNamed:@"video-muted-50x50.png"] forState:UIControlStateNormal];
    }
    else {
        self.connection.videoMuted = false;
        self.isVideoMuted = NO;
        [self.muteVideoButton setImage:[UIImage imageNamed:@"video-active-50x50.png"] forState:UIControlStateNormal];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    self.pendingError = NO;
    [self.presentingViewController dismissViewControllerAnimated:YES
                                                      completion:nil];
}

- (void)timerAction
{
    self.durationLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", self.secondsElapsed / 3600, (self.secondsElapsed % 3600) / 60,
                  (self.secondsElapsed % 3600) % 60];
    self.secondsElapsed++;
    
    if (self.connection && self.connection.state == RCConnectionStateConnected) {
        // not using repeating timer to avoid retain cycles
        self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                              target:self
                                                            selector:@selector(timerAction)
                                                            userInfo:nil
                                                             repeats:NO];
        
    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"invoke-keypad"]) {
        KeypadViewController * keypadViewController = [segue destinationViewController];
        keypadViewController.connection = self.connection;
    }
}


- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

@end
