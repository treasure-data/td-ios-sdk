//
//  TDClient.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 12/15/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KeenClientTD/KeenClient.h"

/**
 * The internal client using for sending requests. Most of the exposed properties could be configured via the container `TreasureData` instance. You probably need this only to tuning the retry parameters.
 */
@interface TDClient : KeenClient

/**
 * The API Key (write-only) uses for this client
 */
@property(nonatomic, strong) NSString *apiKey;

/**
 * The targeting API endpoint, default is https://in.treasuredata.com
 */
@property(nonatomic, strong) NSString *apiEndpoint;

#pragma mark - Retry

/**
 * Enable retry if uploading events failed.
 */
@property BOOL enableRetryUploading;

/**
 * Waiting time for next retry = *`retryIntervalCoefficient`* x `retryIntervalBasebase` ^ `retryTime`
 */
@property int uploadRetryIntervalCoeficient;

/**
 * Wait time for next retry = `retryIntervalCoefficient` x *`retryIntervalBasebase`* ^ `retryTime`
 */
@property int uploadRetryIntervalBase;

/**
 * The max number of retry
 */
@property int uploadRetryCount;

#pragma mark - Deprecated

- (id)initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString*)apiEndpoint DEPRECATED_MSG_ATTRIBUTE("Construct from TreasureData instead.");

/**
 * The pending session of this client.
 */
@property(nonatomic, strong) NSURLSession *session DEPRECATED_MSG_ATTRIBUTE("This will become private property on next version.");

/**
 * Enable compression event data payload on uploading requests.
 */
@property BOOL enableEventCompression DEPRECATED_MSG_ATTRIBUTE("Configure this on TreasureData instead.");

- (void) sendHTTPRequest:(NSURLRequest *)request
            retryCounter:(int)retryCounter
       completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler DEPRECATED_MSG_ATTRIBUTE("Don't call this directly, this will become private on next version.");

@end
