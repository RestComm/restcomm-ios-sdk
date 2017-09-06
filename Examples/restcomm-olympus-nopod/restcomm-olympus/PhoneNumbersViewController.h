//
//  PhoneNumbersViewController.h
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 9/6/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalContact.h"

@protocol PhoneNumbersDelegate <NSObject>

- (void) onPhoneNumberTap:(NSString *)alias andSipUri:(NSString *)sipUri;

@end

@interface PhoneNumbersViewController : UIViewController

@property (nonatomic, weak) id<PhoneNumbersDelegate> phoneNumbersDelegate;

@property (nonatomic, retain) LocalContact  *localContact;

@end
