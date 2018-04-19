//
//  TreasureDataExample.h
//  TreasureDataExample
//
//  Created by Huy Le on 4/17/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

@interface TreasureDataExample : NSObject

+ (void)setupTreasureDataWithEndpoint:(NSString *)endpoint
                               apiKey:(NSString *)apiKey
                             database:(NSString *)database;
@end
