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

#import "LocalMessage.h"

@implementation LocalMessage

- (id)initWithUsername:(NSString *)username message:(NSString *)message type:(NSString *)type{
    self = [super init];
    if (self){
        _username = username;
        _message = message;
        _type = type;
        _time = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.username = [decoder decodeObjectForKey:@"username"];
        self.message = [decoder decodeObjectForKey:@"message"];
        self.type = [decoder decodeObjectForKey:@"type"];
        self.time = [decoder decodeDoubleForKey:@"time"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.username forKey:@"username"];
    [encoder encodeObject:self.message forKey:@"message"];
    [encoder encodeObject:self.type forKey:@"type"];
    [encoder encodeDouble:self.time forKey:@"time"];
}


@end
