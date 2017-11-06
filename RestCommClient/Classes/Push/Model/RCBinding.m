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

#import "RCBinding.h"

@implementation RCBinding

- (id)initWithSid:(NSString *)sid identity:(NSString *)identity applicationSid:(NSString *)applicationSid andAddress:(NSString *)address{
    self = [super init];
    if (self){
        _sid = sid;
        _identity = identity;
        _applicationSid = applicationSid;
        _bindingType = @"apn";
        _address = address;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary{
    self = [super init];
    if (self){
        self.sid = [dictionary objectForKey:@"Sid"];
        self.identity = [dictionary objectForKey:@"Identity"];
        self.applicationSid = [dictionary objectForKey:@"ApplicationSid"];
        self.bindingType = [dictionary objectForKey:@"BindingType"];
        self.address = [dictionary objectForKey:@"Address"];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sid = [decoder decodeObjectForKey:@"sid"];
        self.identity = [decoder decodeObjectForKey:@"identity"];
        self.applicationSid = [decoder decodeObjectForKey:@"applicationSid"];
        self.bindingType = [decoder decodeObjectForKey:@"bindingType"];
        self.address = [decoder decodeObjectForKey:@"address"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sid forKey:@"sid"];
    [encoder encodeObject:self.identity forKey:@"identity"];
    [encoder encodeObject:self.applicationSid forKey:@"applicationSid"];
    [encoder encodeObject:self.bindingType forKey:@"bindingType"];
    [encoder encodeObject:self.address forKey:@"address"];
}

- (NSString *)description {
    return [NSString stringWithFormat: @"RCBinding: sid=%@ identity=%@ applicationSid=%@ bindingType=%@ address=%@",
            self.sid, self.identity, self.applicationSid, self.bindingType, self.address];
}
@end
