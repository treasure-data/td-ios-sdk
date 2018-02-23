//
//  TDConfigurations.m
//  TreasureData
//
//  Created by Huy Le on 1/31/18.
//  Copyright © 2018 Huy Le. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TDConfiguration.h"
#import "TDClient.h"

@implementation TDConfiguration

- (instancetype)init
{
    if (self = [super init]) {
        self.endpoint = @"https://in.treasuredata.com";
        self.autoAppendUniqId = YES;
    }
    return self;
}

- (BOOL)isValid
{
    return [[self violations] count] == 0;
}

- (NSArray<NSString *> *)violations
{
    NSArray * const requiredProps =
    @[NSStringFromSelector(@selector(endpoint)),
      NSStringFromSelector(@selector(encryptionKey)),
      NSStringFromSelector(@selector(defaultDatabase)),
      NSStringFromSelector(@selector(defaultTable))];
    
    NSMutableArray *violations = [NSMutableArray new];
    for (NSString *prop in requiredProps) {
        NSString *violation = [TDConfiguration validateRequire:[self valueForKey:prop] label:prop];
        if (violation) {
            [violations addObject:violation];
        }
    }
    return [violations copy];
}

+ validateRequire:(NSString *)value label:(NSString *)label
{
    if (value == nil) {
        return [NSString stringWithFormat:@"%@ is required", label];
    } else if (value.length == 0) {
        return [NSString stringWithFormat:@"%@ is required but get blank", label];
    } else {
        return nil;
    }
}



@end

