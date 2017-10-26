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

#import "RCApplication.h"

@implementation RCApplication

- (id)initWithSid:(NSString *)sid friendlyName:(NSString *)friendlyName andSandbox:(BOOL)sandbox{
    self = [super init];
    if (self){
        _sid = sid;
        _friendlyName = friendlyName;
        _sandbox = sandbox;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary{
    self = [super init];
    if (self){
        self.sid = [dictionary objectForKey:@"Sid"];
        self.friendlyName = [dictionary objectForKey:@"FriendlyName"];
        self.sandbox = [[dictionary objectForKey:@"Sandbox"] boolValue];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sid = [decoder decodeObjectForKey:@"sid"];
        self.friendlyName = [decoder decodeObjectForKey:@"friendlyName"];
        self.sandbox = [decoder decodeBoolForKey:@"sandbox"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sid forKey:@"sid"];
    [encoder encodeObject:self.friendlyName forKey:@"friendlyName"];
    [encoder encodeBool:self.sandbox forKey:@"sandbox"];
}

- (NSString *)description {
    return [NSString stringWithFormat: @"RCApplication: sid=%@ friendlyName=%@ sandbox=%@", self.sid, self.friendlyName, self.sandbox?@"YES":@"NO"];
}

@end
