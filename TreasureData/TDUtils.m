//
//  TDUtils.m
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Huy Le. All rights reserved.
//

#import "TDUtils.h"

@implementation TDUtils

+ (NSString *)requireNonBlank:(NSString *)str defaultValue:(NSString *)defaultStr message:(NSString *)message
{
    if ([str length] == 0) {
        NSLog(@"%@", message);
        return defaultStr;
    } else {
        return str;
    }
}

@end
