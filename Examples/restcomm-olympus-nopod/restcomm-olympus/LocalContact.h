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

#import <Foundation/Foundation.h>

@interface LocalContact : NSObject<NSCoding>

@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic, retain) NSArray<NSString *> *phoneNumbers; //sip uri or phone numbers
@property (nonatomic, assign) BOOL phoneBookNumber; //if true its number from phone (non editable)
@property (nonatomic, assign) BOOL deleted;


- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName andPhoneNumbers:(NSArray<NSString *> *)phoneNumbers;
- (id)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumbers:(NSArray<NSString *> *)phoneNumbers andIsPhoneBookNumber:(BOOL)isPhoneBookNumber;
@end
