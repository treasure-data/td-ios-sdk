//
//  TDClinet.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 12/15/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeenClientTD/KeenClient.h"

@interface TDClient : KeenClient
@property(nonatomic, strong) NSString *apiKey;
@property(nonatomic, strong) NSString *apiEndpoint;
@property(nonatomic, strong) NSURLSession *session;
@property BOOL enableEventCompression;
@property int uploadRetryIntervalCoeficient;
@property int uploadRetryIntervalBase;
@property int uploadRetryCount;
@property BOOL enableRetryUploading;

- (id)initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString*)apiEndpoint;

- (void) sendHTTPRequest:(NSURLRequest *)request
            retryCounter:(int)retryCounter
       completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
@end
