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

#import "LocalContact.h"


@implementation LocalContact


- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName andPhoneNumbers:(NSArray<NSString *> *)phoneNumbers andIsDefaultNumber:(BOOL)isDefault{
    self = [super init];
    if (self){
        _firstName = firstName;
        _lastName = lastName;
        _phoneNumbers = phoneNumbers;
        _defaultNumber = isDefault;
    }
    return self;
}

- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName andPhoneNumbers:(NSArray<NSString *> *)phoneNumbers{
    return [self initWithFirstName:firstName lastName:lastName andPhoneNumbers:phoneNumbers andIsDefaultNumber:NO];
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.firstName = [decoder decodeObjectForKey:@"firstName"];
        self.lastName = [decoder decodeObjectForKey:@"lastName"];
        self.phoneNumbers = [decoder decodeObjectForKey:@"phoneNumbers"];
        self.deleted = [decoder decodeBoolForKey:@"deleted"];
        self.defaultNumber = [decoder decodeBoolForKey:@"default"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.firstName forKey:@"firstName"];
    [encoder encodeObject:self.lastName forKey:@"lastName"];
    [encoder encodeObject:self.phoneNumbers forKey:@"phoneNumbers"];
    [encoder encodeBool:self.deleted forKey:@"deleted"];
    [encoder encodeBool:self.defaultNumber forKey:@"default"];
}


- (BOOL)isEqualToLocalContact:(LocalContact *)localContact {
    if (!localContact) {
        return NO;
    }
    
    BOOL haveEqualNames = [self.firstName isEqualToString:localContact.firstName];
    BOOL haveEqualLastNames = [self.lastName isEqualToString:localContact.lastName];
    
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
