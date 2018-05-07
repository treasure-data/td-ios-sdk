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

/*!
 * Special table to store TreasureData built-in events: application lifecycle events, audit events
 */
@property(nonatomic, copy) NSString * _Nullable treasureDataTable;

+ (void)initializeWithApiKey:(NSString * _Nonnull)apiKey;

// Can not be null after initializeWithApiKey: has been called.
+ (instancetype _Nonnull)sharedInstance;

+ (void)initializeApiEndpoint:(NSString * _Nullable)apiEndpoint;

- (id _Nonnull)initWithApiKey:(NSString * _Nonnull)apiKey;

- (void)event:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;

- (void)event:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;

- (NSDictionary *)addEvent:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table;

- (NSDictionary *)addEvent:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table;

- (NSDictionary *)addEventWithCallback:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table onSuccess:(void (^ _Nullable)(void))onSuccess onError:(void (^ _Nullable)(NSString* _Nonnull, NSString* _Nullable))onError;

- (NSDictionary *)addEventWithCallback:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table onSuccess:(void (^ _Nullable)(void))onSuccess onError:(void (^ _Nullable)(NSString* _Nonnull, NSString* _Nullable))onError;

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

// - (void)enableAppLifecycleEventsTrackingWithTable:(NSString * _Nonnull)table;

// - (void)disableAppLifecycleEventsTracking;

// - (BOOL)isAppLifecycleEventsTrackingEnabled;

#pragma mark - GDCR Compliance (Right To Be Forgotten)

/*!
 * Disable all the custom events collection (all events except the automatically tracked app lifecycle events)
 * This is a persistent setting so unless being re-enable with `enableCustomEvents`,
 * all your tracked events with `addEvent` will be discarded. (Note that the app lifecycle events will still tracked,
 * call `disableAppLifecycleEvents` to effectively disable all the event collections.
 * Note: `onSuccess` callback will be invoked incase of
 * This feature is supposed to be used for your users to opt-out of the tracking, a requirement for GDPR compliance.
 */
- (void)disableCustomEvents;

/// Re-enable custom events collection if previously disabled
- (void)enableCustomEvents;

/*!
 * Whether the custom events collection is allowed or not.
 * This is a persistent setting, which is able to set via `enableCustomEvents` or `disableCustomEvents`
 */
- (BOOL)areCustomEventsEnabled;

/*!
 * Same as `disableCustomEvents`, this is supposed to be called for your users to opt-out of the automatic tracking.
 */
- (void)disableAppLifecycleEvents;

/// Permanently re-enable event collection if previously disabled
- (void)enableAppLifecycleEvents;

/*!
 * Whether the app lifecycle events collection is allowed or not
 * This is a persistent setting, able to set through `enableAppLifecycleEvent` or `disableAppLifecycleEvent`
 */
- (BOOL)areAppLifecycleEventsEnabled;

/*!
 * Permanently reset the appended "td_uuid" to a different value.
 * Note: this won't reset the current buffered events before this call
 */
- (void)resetUniqId;

@end
