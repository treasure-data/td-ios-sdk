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

@property(nonatomic, strong) TDClient * _Nullable client;

@property(nonatomic, strong) NSString * _Nullable defaultDatabase;

+ (void)initializeWithApiKey:(NSString * _Nonnull)apiKey;

// Can not be null after initializeWithApiKey: has been called.
+ (instancetype _Nonnull)sharedInstance;

+ (void)initializeApiEndpoint:(NSString * _Nullable)apiEndpoint;

- (id _Nonnull)initWithApiKey:(NSString * _Nonnull)apiKey;

- (void)event:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;

- (void)event:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;

- (void)addEvent:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table;

- (void)addEvent:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table;

- (void)addEventWithCallback:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table onSuccess:(void (^ _Nullable)(void))onSuccess onError:(void (^ _Nullable)(NSString* _Nonnull, NSString* _Nullable))onError;

- (void)addEventWithCallback:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table onSuccess:(void (^ _Nullable)(void))onSuccess onError:(void (^ _Nullable)(NSString* _Nonnull, NSString* _Nullable))onError;

- (void)uploadWithBlock:(void (^ _Nonnull)(void))block DEPRECATED_ATTRIBUTE;

- (void)uploadEventsWithBlock:(void (^ _Nonnull)(void))block DEPRECATED_ATTRIBUTE;

- (void)uploadEventsWithCallback:(void (^ _Nullable)(void))onSuccess onError:(void (^ _Nullable)(NSString* _Nonnull, NSString* _Nullable))onError;

- (void)uploadEvents;

- (void)setApiEndpoint:(NSString* _Nonnull)endpoint DEPRECATED_ATTRIBUTE;

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

- (void)startSession:(NSString* _Nonnull)table;

- (void)startSession:(NSString* _Nonnull)table database:(NSString* _Nonnull)database;

- (void)endSession:(NSString* _Nonnull)table;

- (void)endSession:(NSString* _Nonnull)table database:(NSString* _Nonnull)database;

- (NSString * _Nullable)getSessionId;

+ (void)startSession;

+ (void)endSession;

+ (NSString* _Nullable)getSessionId;

+ (void)resetSession;       // Only for test

+ (void)setSessionTimeoutMilli:(long)to;

- (void)enableServerSideUploadTimestamp;

- (void)enableServerSideUploadTimestamp: (NSString* _Nonnull)columnName;

- (void)disableServerSideUploadTimestamp;

- (void)enableAutoAppendRecordUUID;

- (void)enableAutoAppendRecordUUID: (NSString* _Nonnull)columnName;

- (void)disableAutoAppendRecordUUID;

+ (void)disableEventCompression;

+ (void)enableEventCompression;

+ (void)disableLogging;

+ (void)enableLogging;

+ (void)disableTraceLogging;

+ (void)enableTraceLogging;

+ (void)initializeEncryptionKey:(NSString* _Nullable)encryptionKey;

#pragma mark - Auto Tracking

- (void)enableAutoTrackToDatabase:(NSString * _Nonnull)database table:(NSString * _Nonnull)table;

- (void)enableAutoTrackToTable:(NSString * _Nonnull)table;

- (void)disableAutoTrack;

@end
