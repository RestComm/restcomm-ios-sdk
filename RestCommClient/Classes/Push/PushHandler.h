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
 */


#import <Foundation/Foundation.h>
#import "RCRegisterPushDelegate.h"

/**
 *  Handles push notification registration to RestComm
 */
@interface PushHandler: NSObject

/*
 *  Initialize a new PushHandler with parameters and delegate
 *
 * @param parameters      Possible keys: <br>
 * <b>signaling-username</b>: identity (or address of record) for the client, like <i>'sip:ios-sdk@cloud.restcomm.com'</i> <br>
 * <b>firendly-name</b>: name of the client application
 * <b>username"</b>: username, for example: johndoe@telestax.com
 * <b>password</b>: password for an account<br>
 * <b>token</b>: push notification token from the
 * <b>rescomm-account-email</b> account's email
 * <b>push-certificate-public-path</b>: Path where exported APN's public certificate file is installed inside the App bundle.
 * <b>push-certificate-private-path</b>: Path where exported APN's private RSA certificate file is installed inside the App bundle.
 * The certificates are needed in order to receive push notifications. The server is using them to send the push notification to device.
 * <b>is-sandbox</b>:BOOL presented with number ([NSNumber numberWithBool:YES/NO]); It should be true if push certifictes are for development version of the
 * application, if its production it should be set to NO.
 *
 * @param The delegate object that will receive events when registering for push (success, error)
 */
- (id)initWithParameters:(NSDictionary *)parameters andDelegate:(id<RCRegisterPushDelegate>)delegate;

/*
 *  Register device for the push notifications
 */
- (void)registerDevice;

@end
