//
//  TDClinet.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 12/15/14.
//  Copyright (c) 2014 Mitsunori Komatsu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeenClientTD/KeenClient.h"

@interface TDClient : KeenClient
@property(nonatomic, strong) NSString *apiKey;
@property(nonatomic, strong) NSString *apiEndpoint;
@property BOOL enableEventCompression;
@property int uploadRetryIntervalCoeficient;
@property int uploadRetryIntervalBase;
@property int uploadRetryCount;
@property BOOL enableRetryUploading;

- (id)initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString*)apiEndpoint;

- (NSData*) sendHTTPRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error;
@end
