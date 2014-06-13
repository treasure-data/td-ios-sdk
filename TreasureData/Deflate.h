//
//  Deflate.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 6/12/14.
//  Copyright (c) 2014 Treasure Data. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Deflate : NSObject
+ (NSData *) deflate:(NSData *) src;
@end
