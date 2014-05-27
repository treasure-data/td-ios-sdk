//
//  TreasureData.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TreasureData : NSObject

@property(nonatomic, copy) NSString *secret;
@property(nonatomic, copy, readonly) NSDictionary *providers;


+ (void)initializeWithSecret:(NSString *)secret;

+ (instancetype)sharedInstance;

- (void)event:(NSString *)database table:(NSString *)table;

- (void)event:(NSString *)database table:(NSString *)table properties:(NSDictionary *)properties;

- (void)event:(NSString *)database table:(NSString *)table properties:(NSDictionary *)properties options:(NSDictionary *)options;

- (void)uploadWithBlock:(void (^)())block;

- (void)setApiEndpoint:(NSString*)endpoint;

+ (void)disableLogging;

+ (void)enableLogging;

@end
