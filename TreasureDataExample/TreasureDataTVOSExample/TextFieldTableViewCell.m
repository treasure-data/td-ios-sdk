//
//  TextFieldTableViewCell.m
//  TreasureDataTVOSExample
//
//  Created by Tung Vu on 11/9/20.
//  Copyright © 2020 Treasure Data. All rights reserved.
//

#import "TextFieldTableViewCell.h"

@interface TextFieldTableViewCell () <UITextFieldDelegate>
@end

@implementation TextFieldTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    [_textField setHidden:true];
    _textField.delegate = self;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    _onEndEditingBlock(textField.text);
}

@end
