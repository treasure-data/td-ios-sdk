//
//  TDHttpClient.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/29/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TDHttpClient : NSObject <NSURLConnectionDelegate>

- (NSData *)sendRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;

- (void)setLogging:(bool)isLoggingEnabled;

@end
