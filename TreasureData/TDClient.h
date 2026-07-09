//
//  TDClient.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 12/15/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@import KeenClientTD;

/**
 * The internal client using for sending requests. Most of the exposed properties could be configured via the container `TreasureData` instance. You probably need this only to tuning the retry parameters.
 */
@interface TDClient : KeenClient

/**
 * The API Key (write-only) uses for this client
 */
@property(nonatomic, strong) NSString *apiKey;

/**
 * The targeting API endpoint, default is https://us01.records.in.treasuredata.com
 */
@property(nonatomic, strong) NSString *apiEndpoint;

#pragma mark - Tracking

/**
 * Enable tracking td_ip
 */
@property BOOL enableTrackingIP;

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

@end
