//
//  TreasureData.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TreasureData : NSObject

@property(nonatomic, strong) NSString *defaultDatabase;

+ (void)initializeWithSecret:(NSString *)secret;

+ (instancetype)sharedInstance;

- (id)initWithSecret:(NSString *)secret;

- (void)setDefaultDatabase:(NSString*)defaultDatabase;

- (void)event:(NSDictionary *)record database:(NSString *)database table:(NSString *)table;

- (void)event:(NSDictionary *)record table:(NSString *)table;

- (void)uploadWithBlock:(void (^)())block;

- (void)setApiEndpoint:(NSString*)endpoint;

+ (void)disableLogging;

+ (void)enableLogging;

+ (void)disableTraceLogging;

+ (void)enableTraceLogging;

@end
