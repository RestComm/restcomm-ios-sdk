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

#import "AppDelegate.h"
#import "Utils.h"
#import "MainNavigationController.h"
#import "TestFairy/TestFairy.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"application:didFinishLaunchingWithOptions");
    // register the preference defaults early with default values
    [Utils setupUserDefaults];

    // Override point for customization after application launch.
    //[TestFairy begin:@"#TESTFAIRY_APP_TOKEN"];
    
    //register for the push notification
    [self registerForPush];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    //TabBarController * tabBarController = (TabBarController *) self.window.rootViewController;
    //ViewController * viewController = (ViewController *) tabBarController.viewController;
    //[viewController disconnect];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    //TabBarController * tabBarController = (TabBarController *) self.window.rootViewController;
    //ViewController * viewController = (ViewController *) tabBarController.viewController;
    //[viewController connect];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions
{
    NSLog(@"application:willFinishLaunchingWithOptions");

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    NSLog(@"application:openURL:");
    [Utils updatePendingInterappUri:[Utils convertInterappUri2RestcommUri:url]];
    
    return YES;
}

#pragma mark - Push Notification

- (void)registerForPush{
    float ver = [[[UIDevice currentDevice] systemVersion] floatValue];
    if(ver >= 10)
    {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error)
         {
             if( !error )
             {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [[UIApplication sharedApplication] registerForRemoteNotifications]; // required to get the app to do anything at all about push notifications
                 });
                 
                 NSLog( @"Push registration success." );
             }
             else
             {
                 NSLog( @"Push registration FAILED" );
                 NSLog( @"ERROR: %@ - %@", error.localizedFailureReason, error.localizedDescription );
                 NSLog( @"SUGGESTIONS: %@ - %@", error.localizedRecoveryOptions, error.localizedRecoverySuggestion );
             }
         }];
    } else {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(nonnull NSData *)deviceToken{
    NSString * deviceTokenString = [[[[deviceToken description]
                                      stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                     stringByReplacingOccurrencesOfString: @">" withString: @""]
                                    stringByReplacingOccurrencesOfString: @" " withString: @""];

    NSLog(@"The generated device token string is : %@",deviceTokenString);
    
#warning this is only temporarly, we should move logic for RCDevice here; for now, we are sending local notification; and save it to UserDefaults
    NSDictionary *userInfoObj = [NSDictionary dictionaryWithObject:deviceToken forKey:@"deviceTokenString"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TokenReceivedNotification" object:self userInfo:userInfoObj];
    
    NSUserDefaults* appDefaults = [NSUserDefaults standardUserDefaults];
    [appDefaults setObject:deviceTokenString forKey:@"deviceToken"];
    
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Did Fail to Register for Remote Notifications");
    NSLog(@"%@, %@", error, error.localizedDescription);
}

#pragma mark - UNUserNotificationCenter Delegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    NSLog( @"Handle push from foreground" );
    // custom code to handle push while app is in the foreground
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler
{
    NSLog( @"Handle push from background or closed" );
    // if you set a member variable in didReceiveRemoteNotification, you will know if this is from closed or background
}  

@end
