//
//  ViewController.m
//  Sample
//
//  Created by Antonis Tsakiridis on 10/26/16.
//  Copyright © 2016 Telestax Inc. All rights reserved.
//

#import "ViewController.h"


/**/
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
/**/

/*
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *answerButton;
@property (weak, nonatomic) IBOutlet UILabel *callLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property NSString * restcommUrl;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.isRegistered = NO;
    self.isInitialized = NO;
    self.restcommUrl = @"192.168.2.11:5080";
    
    self.parameters = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                       @"antonis", @"aor",
                       @"1234", @"password",
                       nil];
    
    // CHANGEME: set the IP address of your RestComm instance in the URI below
    [self.parameters setObject:self.restcommUrl forKey:@"registrar"];
    
    // initialize RestComm Client by setting up an RCDevice
    self.device = [[RCDevice alloc] initWithParams:self.parameters delegate:self];
    
    self.connection = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(register:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unregister:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

// ---------- UI events
- (IBAction)dialPressed:(id)sender
{
    if (self.connection) {
        NSLog(@"Connection already ongoing");
        return;
    }
    
    // CHANGEME: set the number of the RestComm Application you wish to contact (currently we are using '1235',
    // which is the Hello World RestComm Application). Also set the ip address for your RestComm instance
    [self.parameters setObject:@"sip:+1235@cloud.restcomm.com" forKey:@"username"];
    
    // call the other party
    self.connection = [self.device connect:self.parameters delegate:self];
    
    self.callLabel.text = [NSString stringWithFormat:@"Calling %@", [self.parameters objectForKey:@"username"]];
    self.statusLabel.text = @"Initiating Call...";
}

- (IBAction)hangUpPressed:(id)sender
{
    [self disconnect];
}

- (void)disconnect
{
    if (self.connection) {
        [self.connection disconnect];
        
        self.connection = nil;
        
        self.statusLabel.text = @"Disconnecting Call...";
    }
}

- (void)register:(NSNotification *)notification
{
    [self.device listen];
}

- (void)unregister:(NSNotification *)notification
{
    [self disconnect];
    
    [self.device unlisten];
    self.isRegistered = NO;
}


// ---------- Delegate methods for RC Device
- (void)device:(RCDevice*)device didStopListeningForIncomingConnections:(NSError*)error
{
    
}

// optional
- (void)deviceDidStartListeningForIncomingConnections:(RCDevice*)device
{
}

// received incoming message
- (void)device:(RCDevice *)device didReceiveIncomingMessage:(NSString *)message
{
}

// 'ringing' for incoming connections -let's animate the 'Answer' button to give a hint to the user
- (void)device:(RCDevice*)device didReceiveIncomingConnection:(RCConnection*)connection
{
}

// not implemented yet
- (void)device:(RCDevice *)device didReceivePresenceUpdate:(RCPresenceEvent *)presenceEvent
{
    
}

// ---------- Delegate methods for RC Connection
// not implemented yet
- (void)connection:(RCConnection*)connection didFailWithError:(NSError*)error
{
    
}

// optional
// 'ringing' for outgoing connections
- (void)connectionDidStartConnecting:(RCConnection*)connection
{
    self.statusLabel.text = @"Did start connecting";
}

- (void)connectionDidConnect:(RCConnection*)connection
{
    self.statusLabel.text = @"Connected";
}

- (void)connectionDidDisconnect:(RCConnection*)connection
{
    self.connection = nil;
    self.callLabel.text = @"";
    self.statusLabel.text = @"Disconnected";
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
 */
