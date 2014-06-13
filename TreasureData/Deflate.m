//
//  Deflate.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 6/12/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//
#import <zlib.h>
#import "Deflate.h"

@implementation Deflate
+ (NSData *) deflate:(NSData *) src {
    z_stream zlib;
    zlib.zalloc = Z_NULL;
    zlib.zfree = Z_NULL;
    zlib.opaque = Z_NULL;
    zlib.total_out = 0;
    zlib.next_in = (Bytef *)[src bytes];
    zlib.avail_in = (uInt)[src length];
    int initError = deflateInit2(&zlib, Z_BEST_COMPRESSION, Z_DEFLATED, 15, 9, Z_DEFAULT_STRATEGY);
    
    if(initError != Z_OK) {
        return nil;
    }
    NSMutableData *buf = [NSMutableData dataWithLength:[src length] * 1.02 + 32];
    int status;
    while (1) {
        zlib.next_out = [buf mutableBytes] + zlib.total_out;
        zlib.avail_out = (uInt)([buf length] - zlib.total_out);
        status = deflate(&zlib, zlib.avail_in ? Z_NO_FLUSH : Z_FINISH);
        
        if (status == Z_STREAM_END) {
            break;
        }
        else if (status != Z_OK) {
            NSLog(@"Deflate error");
            deflateEnd(&zlib);
            return nil;
        }
    };
    deflateEnd(&zlib);
    
    [buf setLength:zlib.total_out];
    
    return buf;
}
@end
