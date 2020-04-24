//
//  TreasureData.h
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TDClient.h"
#import "TDRequestOptionsKey.h"

/**
 * Generic success callback block's definition.
 */
typedef void (^SuccessHander)(void);

/**
 * Generic error callback block's definition.
 *
 * Known error codes:
 *
 *  - `init_error`
 *  - `invalid_param`
 *  - `invalid_event`
 *  - `data_conversion`
 *  - `storage_error`
 *  - `network_error`
 *  - `server_response`
 *  - `unknown_error`
 */
typedef void (^ErrorHandler)(NSString* _Nonnull errorCode, NSString* _Nullable errorMessage);

/**
 * The main interface for the SDK. All initialization and configuration (except retry parameters) could be done through here.
 *
 * Minimal example:
 *
 * ```
 * [TreasureData initializeWithApiKey:@"<your_write_only_api_key>"];
 *
 * [[TreasureData sharedInstance] addEvent:@{@"welcome": @"Hello world"}
                                  database:@"my_db"
                                  table:@"my_ios_events"];
 *
 * [[TreasureData sharedInstance] uploadEvents];
 */
@interface TreasureData : NSObject

/**
 * Inner client responsible for uploading events, automatically initialized. Additional parameters like request retrying could be configured here.
 */
@property(nonatomic, strong) TDClient * _Nullable client;

/**
 * The destination database for events that doesn't specify one, default is "td".
 */
@property(nonatomic, strong) NSString * _Nullable defaultDatabase;

/**
 * The destination table for events that doesn't specify one. Currently this also applied for automatically tracked events (if enabled): app lifecycle, IAP and audits, default is "td_ios".
 */
@property(nonatomic, strong) NSString * _Nullable defaultTable;

/**
 * The host to use for the Profile API
 * Defaults to https://cdp.in.treasuredata.com
 *
 * Possible values:
 *    AWS East  https://cdp.in.treasuredata.com
 *    AWS Tokyo https://cdp-tokyo.in.treasuredata.com
 *    AWS EU    https://cdp-eu01.in.treasuredata.com
 *    AWS Asia Pacific (Seoul)  https://cdp-ap02.in.treasuredata.com
 */
@property(nonatomic, strong) NSString * _Nullable cdpEndpoint;

#pragma mark - Initialization

/**
 * Assign the target API endpoint, default is "https://in.treasuredata.com".
 * Possible values:
 *    AWS East  https://in.treasuredata.com
 *    AWS Tokyo https://tokyo.in.treasuredata.com
 *    AWS EU    https://eu01.in.treasuredata.com
 *    AWS Asia Pacific (Seoul)  https://ap02.in.treasuredata.com
 * This have to be call before `initializeWithApiKey(apiKey:)`, otherwise it won't have effect.
 * @param apiEndpoint for the in effect endpoint (`+[TreasureData initializeApiEndpoint:]`).
 */
+ (void)initializeApiEndpoint:(NSString * _Nullable)apiEndpoint;

/**
 * Encrypted the event data in the local persisted buffer.
 * This should be called only once and prior to any `addEvent...` call.
 */
+ (void)initializeEncryptionKey:(NSString* _Nullable)encryptionKey;

/**
 * Initialize `TreasureData.sharedInstance` with the current `apiEndpoint` configured via `+[TreasureData initializeApiEndpoint:]`
 *
 * @param apiKey API Key (only requires `write-only`) for the in effect endpoint (`+[TreasureData initializeApiEndpoint:]`).
 */
+ (void)initializeWithApiKey:(NSString * _Nonnull)apiKey;

/**
 * The default singleton SDK instance.
 *
 * You could create multiple instances that target different endpoints (and of course apiKey, and default database, table, etc.) with `-[TreasureData initWithApiKey:]`,
 * but mind that `+[TreasureData initializeApiEndpoint:]` is shared have to be called before `-[TreasureData initWithApiKey:]` to be affected.
 */
+ (instancetype _Nonnull)sharedInstance;

/**
 * Construct a new `TreasureData` instance.
 *
 * @param apiKey for the in effect endpoint (`+[TreasureData initializeApiEndpoint:]`).
 */
- (id _Nonnull)initWithApiKey:(NSString * _Nonnull)apiKey;

#pragma mark - Tracking events

/**
 * Track a new event
 *
 * @param record event data
 * @param database the event's destination database
 * @param table the event's destination table
 */
- (NSDictionary *_Nullable)addEvent:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table;

/**
 * Track a new event targets `TreasureData.defaultDatabase`
 *
 * @param record event data
 * @param table the event's destination table
 */
- (NSDictionary *_Nullable)addEvent:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table;

/**
 * Track a new event with status handlers.
 *
 * Note that `addEvent...` methods doesn't involve network operations,
 * failures here may indicate misconfigurations causing the event to not be inserted on the local buffer.
 * For `TreasureData` instances that are purposedly disabled:
 *
 * - `-[TreasureData disableCustomEvent]`
 *
 * This will silently return `nil` without invoking the `onError` handler.
 *
 * @param record event data
 * @param database the event's destination database
 * @param table the event's destination table
 * @param onSuccess get called (on main thread) when the event successfuly inserted to the local buffer
 * @param onError get called (on main thread) when the event failed to inserted to the local buffer, perfer `ErrorHandler` for possible error codes
 */
- (NSDictionary *_Nullable)addEventWithCallback:(NSDictionary * _Nonnull)record
                              database:(NSString * _Nonnull)database
                                 table:(NSString * _Nonnull)table
                             onSuccess:(SuccessHander _Nullable)onSuccess
                               onError:(ErrorHandler _Nullable)onError;

/**
 * Same as `-[TreasureData addEventWithCallback:database:table:onSuccess:onError]`, targets the `TreasureData.defaultDatabase`.
 *
 * @param record event data
 * @param table the event's destination table
 * @param onSuccess get called (on main thread) when the event successfuly inserted to the local buffer
 * @param onError get called (on main thread) when the event failed to inserted to the local buffer, perfer `ErrorHandler` for possible error codes
 */
- (NSDictionary *_Nullable)addEventWithCallback:(NSDictionary * _Nonnull)record
                                 table:(NSString * _Nonnull)table
                             onSuccess:(SuccessHander _Nullable)onSuccess
                               onError:(ErrorHandler _Nullable)onError;

/**
 * Same as `-[TreasureData addEventWithCallback:database:table:onSuccess:onError]`, targets the `TreasureData.defaultDatabase` / `TreasureData.defaultTable`.
 *
 * @param onSuccess get called (on main thread) when the event successfuly uploaded to the configured endpoint. Notes that it doesn't guarantee events to be successfully persisted to the remote database, it only indicates that the server accepted the request (without checking the validity of the events).
 *
 * @param onError get called (on main thread) when the event failed to inserted to the configured endpoint, perfer `ErrorHandler` for possible error codes
 */
- (void)uploadEventsWithCallback:(SuccessHander _Nullable)onSuccess
                         onError:(ErrorHandler _Nullable)onError;

/**
 * Same as `-[TreasureData uploadEventWithCallback:onError:]` but ignores the result status.
 */
- (void)uploadEvents;

#pragma mark - Events' metadata

/**
 * Get UUID generated from TreasureData. The value will be set to `td_uuid` column for every events if `enableAutoAppendUniqId` is called.
 */
- (NSString *_Nonnull)getUUID;

/**
 * Automaticaly append `td_uuid` column for every events. The value is randomly generated and persisted, it is shared across app launches and events. Basically, it is used to prepresent for a unique app installation instance.
 *
 * This is disabled by default.
 */
- (void)enableAutoAppendUniqId;

/**
 * Disable the auto appended `td_uuid` column.
 */
- (void)disableAutoAppendUniqId;

/**
 * Permanently reset the appended `td_uuid` column to a different value.
 * Note: this won't reset the current buffered events before this call
 */
- (void)resetUniqId;

/**
 * Disable these auto appended columns:
 *
 * - `td_device`, `td_model`: current these share a same value, extracted from `UIDevice.currentDevice.model`. Example: "iPhone", "iPad",...
 * - `td_os_version`: Extracted from `UIDevice.currentDevice.systemVersion`. Example: "11.4.1", "12.1.4",...
 * - `td_os_type`: Always "iOS"
 */
- (void)enableAutoAppendModelInformation;

/**
 * Disable the auto appended `td_device`, `td_model`, `td_os_version`, `td_os_type` columns.
 */
- (void)disableAutoAppendModelInformation;

/**
 * Automatically append these columns:
 *
 * - `td_app_ver`: extracted from main bundle's `CFBundleShortVersionString` entry
 * - `td_app_ver_num`: extracted from main bundle's `CFBundleVersion` entry
 *
 * This is disabled by default.
 */
- (void)enableAutoAppendAppInformation;

/**
 * Disable these auto appended `td_app_ver` and `td_app_ver_num` column
 */
- (void)disableAutoAppendAppInformation;

/**
 * Automatically append these columns:
 * - `td_locale_country`: ISO 3166-1's code, extracted from `NSLocale.currentLocale`'s `NSLocaleCountryCode`. Example: "USA", "AUS",...
 * - `td_locale_language: ISO 639-1's code, extracted from `NSLocal.currentLocal`'s `NSLocaleLanguageCode`. Example: "es", "en",...
 *
 * This is disabled by default.
 */
- (void)enableAutoAppendLocaleInformation;

/**
 * Disable the auto appended `td_locale_country` and `td_locale_language` columns.
 */
- (void)disableAutoAppendLocaleInformation;

/**
 * Automatically append the time value when the event is received on server. Disabled by default.
 *
 * @param columnName The column to write the uploaded time value
 */
- (void)enableServerSideUploadTimestamp: (NSString* _Nonnull)columnName;

/**
 * Automatically append the time when the event is received on server. Disabled by default.
 *
 * This is disabled by default.
 */
- (void)enableServerSideUploadTimestamp;

/**
 * Disable the uploading time column
 */
- (void)disableServerSideUploadTimestamp;

/**
 * Automatically append a random and unique ID for each event. Disabled by default.
 *
 * @param columnName The column to write the ID
 */
- (void)enableAutoAppendRecordUUID: (NSString* _Nonnull)columnName;

/**
 * Same as `-[TreasureData enableAutoAppendRecordUUID:], using "record_uuid" as the column name.
 */
- (void)enableAutoAppendRecordUUID;

/**
 * Disable appending ID for each event.
 */
- (void)disableAutoAppendRecordUUID;

/**
 * Automatically append device's advertising identifer, a.k.a IDFA, using "td_maid" as the default column name.
 *
 */
- (void)enableAutoAppendAdvertisingIdentifier;

/**
 * Automatically append device's advertising identifer, a.k.a IDFA.
 *
 * @param columnName The column to write the advertising identifier
 */
- (void)enableAutoAppendAdvertisingIdentifier:(NSString* _Nonnull)columnName;

/**
 * Disable automatically append device's advertising identifer, a.k.a IDFA.
 */
- (void)disableAutoAppendAdvertisingIdentifier;

#pragma mark - Session

/**
 * Start to a new session for this `TreasureData`'s instance
 
 * Every subsequent events tracked from this instance will be appended a same random and unique value to `td_session_id` column. An additional event of `{"td_session_event": "start"} will also be tracked, target the specified table and database.
 *
 * @param table Destination table for the `td_session_event`
 * @param database Destination database for the `td_session_event`
 */
- (void)startSession:(NSString* _Nonnull)table database:(NSString* _Nonnull)database;

/**
 * Same as `-[TreasureData startSession:database:]`, using `TreasureData.defaultDatabase` as the destination database for `td_session_event`.
 */
- (void)startSession:(NSString* _Nonnull)table;

/**
 * End this `TresureData` instance's session. Track an additional event of `{"td_session_event": "end"}` to the specified database and table.
 * Note that event if the instance's session is ended, `td_session_event` still could be appended if the static session (`+[TreasureData startSession]`) is in effect.
 *
 * @param table Destination table for the `td_session_event`
 * @param database Destination database for the `td_session_event`
 */

- (void)endSession:(NSString* _Nonnull)table database:(NSString* _Nonnull)database;

/**
 * Same as `-[TreasureData endSession]`, using `TreasureData.defaultDatbase` as the destination database for `td_session_event`.
 */
- (void)endSession:(NSString* _Nonnull)table;

/**
 * Get this instance's current session ID.
 */
- (NSString * _Nullable)getSessionId;

/**
 * Start a static session that is shared across `TreasureData` instances. Unlike instance's session, there will be no `td_session_event` tracked.
 */
+ (void)startSession;

/**
 * End the current static session. Unlike instance's session, there will be no `td_session_event` tracked.
 */
+ (void)endSession;

/**
 * Get the current static session ID.
 */
+ (NSString* _Nullable)getSessionId;

/**
 * Set the minimal time window that the static session stays alive.
 *
 * @param to The session timeout, default is 10 seconds
 */
+ (void)setSessionTimeoutMilli:(long)to;

#pragma mark - Automatically tracked events

/**
 * Re-enable custom events collection if previously disabled
 */
- (void)enableCustomEvent;

/**
 * Disable custom events collection (ones that called manually with `addEvent...`).
 * This is a persistent setting so unless being re-enable with `enableCustomEvent`,
 * all your tracked events with `addEvent` will be discarded. (Note that the app lifecycle events will still tracked,
 * call `disableAppLifecycleEvent` to effectively disable all the event collections.
 * This feature is supposed to be used for your users to opt-out of the tracking, a requirement for GDPR compliance.
 */
- (void)disableCustomEvent;

/**
 * Whether the custom events collection is allowed or not.
 * This is a persistent setting, which is able to set via `enableCustomEvent` or `disableCustomEvent`
 */
- (BOOL)isCustomEventEnabled;


/**
 * Enable tracking app lifecycle events. This setting is persited, default is disabled.
 */
- (void)enableAppLifecycleEvent;

/**
 * Same as `disableCustomEvent`, this is supposed to be called for your users to opt-out of the automatic tracking.
 */
- (void)disableAppLifecycleEvent;

/**
 * Whether the app lifecycle events collection is allowed or not
 * This is a persistent setting, able to set through `enableAppLifecycleEvent` or `disableAppLifecycleEvent`
 */
- (BOOL)isAppLifecycleEventEnabled;

/**
 * Enable tracking `SKPaymentTransactionStatePurchased` event automatically. This is disabled by default. Unlike custom and app lifecycle events, this settings is not persisted.
 *
 * An example IAP event record:
 * ```
 * "td_ios_event": "TD_IOS_IN_APP_PURCHASE",
 * "td_iap_transaction_identifier": "1000000514091400",
 * "td_iap_transaction_date": "2019-03-28T08:44:12+07:00",
 * "td_iap_quantity": 1,
 * "td_iap_product_identifier": "com.yourcompany.yourapp.yourproduct", ,
 * "td_iap_product_price": 0.99,
 * "td_iap_product_localized_title": "Your Product Title",
 * "td_iap_product_localized_description": "Your Product Description",
 * "td_iap_product_currency_code": "USD",  // this is only available on iOS 10 and above
 */
- (void)enableInAppPurchaseEvent;

/**
 * Disable tracking IAP events
 */
- (void)disableInAppPurchaseEvent;

/**
 * Whether this `TreasureData`'s instance tracking IAP events
 */
- (BOOL)isInAppPurchaseEventEnabled;

#pragma mark - Personalization API

/**
 * Fetch user segments from cdp endpoint. Callback with either a JSON serialized object or an error.
 *
 * @warning This will make a call to shared instance's cdpEndpoint. Make sure you configure cdpEndpoint before using this method
 * @param audienceTokens List of audience tokens. There must be at least one token.
 * @param Profiles' keys as specified in key column.
 * @param options Request options. For possible options, see TDRequestOptionsKey.
 * @param handler Completion callback with either JSON object or an error. The callback will be called from the caller's queue, or if there is no queue, default to main queue.
 */
- (void)fetchUserSegments: (nonnull NSArray<NSString *> *)audienceTokens
                     keys: (nonnull NSDictionary<NSString *, id> *)keys
                  options: (nullable NSDictionary<TDRequestOptionsKey, id> *)options
        completionHandler: (void (^_Nonnull)(NSArray* _Nullable jsonResponse, NSError* _Nullable error)) handler
        NS_SWIFT_NAME(fetchUserSegments(tokens:keys:options:completionHandler:));

#pragma mark - Misc.

/**
 * Enable retrying on failed uploads. Already enabled by default.
 *
 * Use `TreasureData.client` for fine tuning retry's configuration
 */
- (void)enableRetryUploading;

/**
 * Do not attempt to retry on failed uploads.
 *
 * Use `TreasureData.client` for fine tuning retry's configuration
 */
- (void)disableRetryUploading;

/**
 * Event data will be compressed with zlib before uploading to server.
 */
+ (void)enableEventCompression;

/**
 * Event data will be uploaded in it's full format.
 */
+ (void)disableEventCompression;

/**
 * Enable client logging. Disabled by default.
 */
+ (void)enableLogging;

/**
 * Disable client's logging/
 */
+ (void)disableLogging;

/**
 * Enable trace logging
 */
+ (void)enableTraceLogging;

/**
 * Disable trace logging
 */
+ (void)disableTraceLogging;

- (BOOL)isFirstRun;
- (void)clearFirstRun;

#pragma mark - Deprecated

- (void)event:(NSDictionary * _Nonnull)record database:(NSString * _Nonnull)database table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;
- (void)event:(NSDictionary * _Nonnull)record table:(NSString * _Nonnull)table DEPRECATED_ATTRIBUTE;
- (void)uploadWithBlock:(void (^ _Nonnull)(void))block DEPRECATED_ATTRIBUTE;
- (void)uploadEventsWithBlock:(void (^ _Nonnull)(void))block DEPRECATED_ATTRIBUTE;
- (void)setApiEndpoint:(NSString* _Nonnull)endpoint DEPRECATED_ATTRIBUTE;


@end
