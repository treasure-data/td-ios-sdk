//
//  TDClientInternal.h
//  TreasureData
//
//  Created by huylenq on 4/5/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//


@interface TDClient (Internal)

- (void)__enableEventCompression:(BOOL)flag;

- (instancetype)__initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString*)apiEndpoint;

- (NSURLSession *)__session;
- (void)__setSession:(NSURLSession *)session;

@end
