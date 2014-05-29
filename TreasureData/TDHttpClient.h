//
//  TDHttpClient.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/29/14.
//  Copyright (c) 2014 Mitsunori Komatsu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TDHttpClient : NSObject <NSURLConnectionDelegate>
@property(nonatomic, strong) NSURLConnection *conn;
// TODO: handle multi requests
@property(nonatomic, strong) NSData *responseData;
@property(nonatomic, strong) NSURLResponse *response;
@property(nonatomic, strong) NSError *error;
@property BOOL isFinished;

- (NSData *)sendRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;
@end
