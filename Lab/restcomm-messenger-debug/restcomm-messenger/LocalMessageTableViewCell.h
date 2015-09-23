//
//  LocalMessageTableViewCell.h
//  restcomm-messenger
//
//  Created by Antonis Tsakiridis on 9/23/15.
//  Copyright © 2015 TeleStax. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LocalMessageTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *senderImage;
@property (weak, nonatomic) IBOutlet UITextView *senderText;

@end
