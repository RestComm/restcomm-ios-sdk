//
//  LocalContact.m
//  restcomm-olympus
//
//  Created by Manevski Ognjen on 9/5/17.
//  Copyright © 2017 TeleStax. All rights reserved.
//

#import "LocalContact.h"


@implementation LocalContact

- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName andPhoneNumbers:(NSArray<NSString *> *)phoneNumbers{
    self = [super init];
    if (self){
        _firstName = firstName;
        _lastName = lastName;
        _phoneNumbers = phoneNumbers;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.firstName = [decoder decodeObjectForKey:@"firstName"];
        self.lastName = [decoder decodeObjectForKey:@"lastName"];
        self.phoneNumbers = [decoder decodeObjectForKey:@"phoneNumbers"];
        self.deleted = [decoder decodeBoolForKey:@"deleted"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.firstName forKey:@"firstName"];
    [encoder encodeObject:self.lastName forKey:@"lastName"];
    [encoder encodeObject:self.phoneNumbers forKey:@"phoneNumbers"];
    [encoder encodeBool:self.deleted forKey:@"deleted"];
}


- (BOOL)isEqualToLocalContact:(LocalContact *)localContact {
    if (!localContact) {
        return NO;
    }
    
    BOOL haveEqualNames = (!self.firstName && !localContact.firstName) || [self.firstName isEqualToString:localContact.firstName];
    BOOL haveEqualLastNames = (!self.lastName && !localContact.lastName) || [self.lastName isEqualToString:localContact.lastName];
    
    return haveEqualNames && haveEqualLastNames;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[LocalContact class]]) {
        return NO;
    }
    
    return [self isEqualToLocalContact:(LocalContact *)object];
}

- (NSUInteger)hash
{
    NSUInteger result = 1;
    NSUInteger prime = 31;
    
    result = prime * result + [self.firstName hash];
    result = prime * result + [self.lastName hash];
    
    return result;
}

@end
