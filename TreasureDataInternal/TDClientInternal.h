//
//  TDClientInternal.h
//  TreasureData
//
//  Created by huylenq on 4/5/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//


@interface TDClient (Internal)

- (void)__enableEventCompression:(BOOL)flag;

- (nonnull instancetype)__initWithApiKey:(nonnull NSString *)apiKey apiEndpoint:(nonnull NSString*)apiEndpoint;

/// Swift-friendly factory (Swift imports this as `TDClient(apiKey:apiEndpoint:)`).
+ (nonnull instancetype)clientWithApiKey:(nonnull NSString *)apiKey apiEndpoint:(nonnull NSString *)apiEndpoint;

- (nullable NSURLSession *)__session;
- (void)__setSession:(nullable NSURLSession *)session;

@end
