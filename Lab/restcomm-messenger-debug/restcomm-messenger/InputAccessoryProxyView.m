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

#import "InputAccessoryProxyView.h"

// Check Apple documentation on 'Custom Views for Data Input' for more info on how to implement this

@interface InputAccessoryProxyView()
// (Apple doc) Custom view classes (and other subclasses that inherit from UIResponder) should redeclare one or both
// of these properties and their backing instance variables...
@property (nonatomic, readwrite, retain) UIView *inputAccessoryView;
@end

@implementation InputAccessoryProxyView

- (id)initWithFrame:(CGRect)rect viewController:(MessageViewController *)viewController;
{
    self = [super initWithFrame:rect];
    self.viewController = viewController;
    return self;
}

// Allow this view to be a responder
- (BOOL) canBecomeFirstResponder
{
    return true;
}

// (Apple doc) ... and override the getter method for the property —that is, don’t synthesize the properties’ accessor methods.
// In their getter-method implementations, they should return it the view, loading or creating it if it doesn’t
// already exist
- (UIView *)inputAccessoryView
{
    if (!_inputAccessoryView) {
        // instantiate the .xib and use our view controller as 'File's Owner'
        NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:@"InputAccessoryFragment"
                                                             owner:self.viewController
                                                           options:nil];
        UIView *accessoryFragment = [nibContents objectAtIndex:0];
        // determine origin.y by subtracting the fragment height from the full frame height
        accessoryFragment.frame = CGRectMake(accessoryFragment.frame.origin.x, accessoryFragment.frame.size.height - accessoryFragment.frame.size.height,
                                             accessoryFragment.frame.size.width, accessoryFragment.frame.size.height);
        // use the ivar as the getter (i.e. self.inputAccessoryView) would trigger this methos again
        _inputAccessoryView = accessoryFragment;
        
    }
    return _inputAccessoryView;
}

@end
