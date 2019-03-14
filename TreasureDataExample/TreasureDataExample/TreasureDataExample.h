//
//  TreasureDataExample.h
//  TreasureDataExample
//
//  Created by Huy Le on 4/17/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TreasureDataExample : NSObject

@property (nonatomic, strong) NSString *testTable;

+ (void)setupTreasureData;

+ (NSString *)testTable;

+ (void)setTestTable:(NSString *)table;

+ (NSSet<NSString *> *)productIds;


@end
