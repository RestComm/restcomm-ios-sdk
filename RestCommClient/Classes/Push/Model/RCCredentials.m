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

#import "RCCredentials.h"

@implementation RCCredentials

- (id)initWithSid:(NSString *)sid applicationSid:(NSString *)applicationSid credentialType:(NSString *)credentialType certificate:(NSString *)certificate andPrivateKey:(NSString *)privateKey{
    self = [super init];
    if (self){
        _sid = sid;
        _applicationSid = applicationSid;
        _credentialType = credentialType;
        _certificate = certificate;
        _privateKey = privateKey;
    }
    return self;
}


- (id)initWithDictionary:(NSDictionary *)dictionary{
    self = [super init];
    if (self){
        self.sid = [dictionary objectForKey:@"Sid"];
        self.applicationSid = [dictionary objectForKey:@"ApplicationSid"];
        self.credentialType = [dictionary objectForKey:@"CredentialType"];
        self.certificate = [dictionary objectForKey:@"Certificate"];
        self.privateKey = [dictionary objectForKey:@"PrivateKey"];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sid = [decoder decodeObjectForKey:@"sid"];
        self.applicationSid = [decoder decodeObjectForKey:@"applicationSid"];
        self.credentialType = [decoder decodeObjectForKey:@"credentialType"];
        self.certificate = [decoder decodeObjectForKey:@"certificate"];
        self.privateKey = [decoder decodeObjectForKey:@"privateKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sid forKey:@"sid"];
    [encoder encodeObject:self.applicationSid forKey:@"applicationSid"];
    [encoder encodeObject:self.credentialType forKey:@"credentialType"];
    [encoder encodeObject:self.certificate forKey:@"certificate"];
    [encoder encodeObject:self.privateKey forKey:@"privateKey"];
}

@end
