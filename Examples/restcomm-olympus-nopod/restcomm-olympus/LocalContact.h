//
//  LocalContact.h
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 9/5/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocalContact : NSObject<NSCoding>

@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic, retain) NSArray<NSString *> *phoneNumbers; //sip uri or phone numbers
@property (nonatomic, assign) BOOL deleted;

- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName andPhoneNumbers:(NSArray<NSString *> *)phoneNumbers;
@end
