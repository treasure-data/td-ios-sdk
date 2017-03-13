//
//  TreasureData.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TDClient.h"

@interface TreasureData : NSObject

@property(nonatomic, strong) TDClient *client;

@property(nonatomic, strong) NSString *defaultDatabase;

+ (void)initializeWithApiKey:(NSString *)apiKey;

+ (instancetype)sharedInstance;

+ (void)initializeApiEndpoint:(NSString *)apiEndpoint;

- (id)initWithApiKey:(NSString *)apiKey;

- (void)setDefaultDatabase:(NSString*)defaultDatabase;

- (void)event:(NSDictionary *)record database:(NSString *)database table:(NSString *)table DEPRECATED_ATTRIBUTE;

- (void)event:(NSDictionary *)record table:(NSString *)table DEPRECATED_ATTRIBUTE;

- (void)addEvent:(NSDictionary *)record database:(NSString *)database table:(NSString *)table;

- (void)addEvent:(NSDictionary *)record table:(NSString *)table;

- (void)addEventWithCallback:(NSDictionary *)record database:(NSString *)database table:(NSString *)table onSuccess:(void (^)())onSuccess onError:(void (^)(NSString*, NSString*))onError;

- (void)addEventWithCallback:(NSDictionary *)record table:(NSString *)table onSuccess:(void (^)())onSuccess onError:(void (^)(NSString*, NSString*))onError;

- (void)uploadWithBlock:(void (^)())block DEPRECATED_ATTRIBUTE;

- (void)uploadEventsWithBlock:(void (^)())block DEPRECATED_ATTRIBUTE;

- (void)uploadEventsWithCallback:(void (^)())onSuccess onError:(void (^)(NSString*, NSString*))onError;

- (void)uploadEvents;

- (void)setApiEndpoint:(NSString*)endpoint DEPRECATED_ATTRIBUTE;

- (void)disableAutoAppendUniqId;

- (void)enableAutoAppendUniqId;

- (void)disableAutoAppendModelInformation;

- (void)enableAutoAppendModelInformation;

- (void)enableAutoAppendAppInformation;

- (void)disableAutoAppendAppInformation;

- (void)enableAutoAppendLocaleInformation;

- (void)disableAutoAppendLocaleInformation;

- (void)disableRetryUploading;

- (void)enableRetryUploading;

- (BOOL)isFirstRun;

- (void)clearFirstRun;

- (void)initializeFirstRun;     // Only for test

- (void)startSession:(NSString*)table;

- (void)startSession:(NSString*)table database:(NSString*)database;

- (void)endSession:(NSString*)table;

- (void)endSession:(NSString*)table database:(NSString*)database;

- (NSString *)getSessionId;

+ (void)startSession;

+ (void)endSession;

+ (NSString*)getSessionId;

+ (void)resetSession;       // Only for test

+ (void)setSessionTimeoutMilli:(long)to;

- (void)enableServerSideUploadTimestamp;

- (void)enableServerSideUploadTimestamp: (NSString*)columnName;

- (void)disableServerSideUploadTimestamp;

- (void)enableAutoAppendRecordUUID;

- (void)enableAutoAppendRecordUUID: (NSString*)columnName;

- (void)disableAutoAppendRecordUUID;

+ (void)disableEventCompression;

+ (void)enableEventCompression;

+ (void)disableLogging;

+ (void)enableLogging;

+ (void)disableTraceLogging;

+ (void)enableTraceLogging;

+ (void)initializeEncryptionKey:(NSString*)encryptionKey;
@end
