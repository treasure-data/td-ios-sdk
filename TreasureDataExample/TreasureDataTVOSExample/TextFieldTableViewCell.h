//
//  TextFieldTableViewCell.h
//  TreasureDataExample
//
//  Created by Tung Vu on 11/9/20.
//  Copyright © 2020 Treasure Data. All rights reserved.
//

#ifndef TextFieldTableViewCell_h
#define TextFieldTableViewCell_h

@import UIKit;

@interface TextFieldTableViewCell: UITableViewCell
@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, copy) void(^onEndEditingBlock)(NSString *);
@end

#endif /* TextFieldTableViewCell_h */
