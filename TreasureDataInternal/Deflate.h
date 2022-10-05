//
//  Deflate.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 6/12/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Deflate : NSObject
+ (NSData *) deflate:(NSData *) src;
@end
