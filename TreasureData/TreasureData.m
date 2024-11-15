//
//  TreasureData.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TreasureData.h"
#import "TDClient.h"
#import "TDSession.h"
#import "TDUtils.h"
#import "TDConstants.h"
#import "TDIAPObserver.h"
#import "TDClientInternal.h"
#import "NSString+TDHelpers.h"
#import <AdSupport/ASIdentifierManager.h>

static bool isTraceLoggingEnabled = false;
static bool isEventCompressionEnabled = true;
static TreasureData *sharedInstance = nil;
static NSString *tableNamePattern = @"[^0-9a-z_]";
static NSString *defaultApiEndpoint = @"https://us01.records.in.treasuredata.com";
static NSString *defaultCdpEndpoint = @"https://cdp.in.treasuredata.com";
static NSString *storageKeyOfUuid = @"td_sdk_uuid";
static NSString *storageKeyOfFirstRun = @"td_sdk_first_run";
static NSString *keyOfLocalTimestamp = @"time";
static NSString *keyOfUuid = @"td_uuid";
static NSString *keyOfAdvertisingIdentifier = @"td_maid";
static NSString *keyOfBoard = @"td_board";
static NSString *keyOfBrand = @"td_brand";
static NSString *keyOfDevice = @"td_device";
static NSString *keyOfDisplay = @"td_display";
static NSString *keyOfModel = @"td_model";
static NSString *keyOfOsVer = @"td_os_ver";
static NSString *keyOfOsType = @"td_os_type";
static NSString *keyOfAppVer = @"td_app_ver";
static NSString *keyOfAppVerNum = @"td_app_ver_num";
static NSString *keyOfPreviousAppVer = @"td_app_previous_ver";
static NSString *keyOfPreviousAppVerNum = @"td_app_previous_ver_num";
static NSString *keyOfLocaleCountry = @"td_locale_country";
static NSString *keyOfLocaleLang = @"td_locale_lang";
static NSString *keyOfSessionId = @"td_session_id";
static NSString *keyOfSessionEvent = @"td_session_event";
static NSString *sessionEventStart = @"start";
static NSString *sessionEventEnd = @"end";
static Session *session = nil;
static long sessionTimeoutMilli = -1;
static NSString *TreasureDataErrorDomain = @"com.treasuredata";

@interface TreasureData ()

@property NSString *autoAppendLocalTimestampColumn;
@property BOOL autoAppendUniqId;
@property BOOL autoAppendModelInformation;
@property BOOL autoAppendAppInformation;
@property BOOL autoAppendLocaleInformation;
@property NSString *sessionId;
@property NSString *autoAppendRecordUUIDColumn;
@property NSString *autoAppendAdvertisingIdColumn;

@property (nonatomic, assign, getter=isCustomEventEnabled) BOOL customEventEnabled;
@property (nonatomic, assign, getter=isAppLifecycleEventEnabled) BOOL appLifecycleEventEnabled;
@property (nonatomic, assign, getter=isInAppPurchaseEventEnabled) BOOL inAppPurchaseEnabled;

@property (nonatomic, strong) dispatch_queue_t addEventQueue;

@end

@implementation TreasureData {
    NSString * _UUID;
    TDIAPObserver * _iapObserver;
    NSMutableDictionary *_defaultValues;
}


- (instancetype)initWithApiKey:(NSString *)apiKey {
    self = [self initWithApiKey:apiKey apiEndpoint:defaultApiEndpoint];
    return self;
}

- (instancetype)initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString *)apiEndpoint {
    self = [self init];
    
    if (self) {
        /*
         * This client uses the parent's resources as follows:
         *
         *  - global_dispatch_queue
         *    - Although the client uses the same label when calling dispatch_queue_create(),
         *      dispatch_queue_create() returns the different queue and there is no conflict with
         *      the parent client.
         *
         *  - cache directory
         *    - Although the client uses the same root directory,
         *      the client uses a special project id which is not conflicted with
         *      the parent client's project ids.
         *
         */
        
        [self enableAutoAppendLocalTimestamp];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED] != nil) {
            self.customEventEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED];
        } else {
            // Unless being explicitly disabled, custom events are allowed
            self.customEventEnabled = YES;
        }
        
        // Unlike custom events, app lifecycle events must be explicitly enabled
        self.appLifecycleEventEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:TD_USER_DEFAULTS_KEY_APP_LIFECYCLE_EVENT_ENABLED];
        
        self.client = [[TDClient alloc] __initWithApiKey:apiKey
                                             apiEndpoint:apiEndpoint];
        if (self.client) {
            
        } else {
            KCLog(@"Failed to initialize client");
        }
        [self observeLifecycleEvents];
        
        self.addEventQueue = dispatch_queue_create("com.treasuredata.add_event", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)event:(NSDictionary *)record table:(NSString *)table {
    [self addEvent:record table:table];
}

- (void)event:(NSDictionary *)record database:(NSString *)database table:(NSString *)table {
    [self addEvent:record database:database table:table];
}

- (NSDictionary *)addEvent:(NSDictionary *)record table:(NSString *)table {
    return [self addEvent:record database:self.defaultDatabase table:table];
}

- (NSDictionary *)addEvent:(NSDictionary *)record
                  database:(NSString *)database
                     table:(NSString *)table {
    return [self addEventWithCallback:record database:database table:table onSuccess:nil onError:nil];
}

- (NSDictionary *)addEventWithCallback:(NSDictionary *)record table:(NSString *)table onSuccess:(void (^)(void))onSuccess onError:(void (^)(NSString*, NSString*))onError {
    return [self addEventWithCallback:record database:self.defaultDatabase table:table onSuccess:onSuccess onError:onError];
}

// TOOD: make this (it it's family) async, seldomly the return event record actually get used
- (NSDictionary *)addEventWithCallback:(NSDictionary *)record
                              database:(NSString *)database
                                 table:(NSString *)table
                             onSuccess:(SuccessHander)onSuccess
                               onError:(ErrorHandler)onError {
    NSDictionary __block *event = nil;

    SuccessHander success = ^{
        if (onSuccess) {
            if ([NSThread isMainThread]) {
                onSuccess();
            } else {
                dispatch_sync(dispatch_get_main_queue(), onSuccess);
            }
        }
    };
    ErrorHandler error = ^void(NSString *errorCode, NSString* errorMessage) {
        if (onError) {
            if ([NSThread isMainThread]) {
                onError(errorCode, errorMessage);
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    onError(errorCode, errorMessage);
                });
            }
        }
    };

    // Dispatch to a dedicated queue as this may do some potentially intensive calculations.
    //
    // For now this doesn't benefit much as it still blocks the caller thread,
    // we would want to change this to dispatch_async later, as a consequence, the return has to be void.
    dispatch_sync(self.addEventQueue, ^{
        @try {
            if ([TDUtils isCustomEvent:record] && ![self isCustomEventEnabled]) {
                error(TD_ERROR_CUSTOM_EVENT_DISABLED,
                            @"You configured to deny tracking of custom events. This is a persistent setting, it will unharmfully drop the any custom events called through `addEvent...` methods family.");
                return;
            }

            if ([TDUtils isAppLifecycleEvent:record] && ![self isAppLifecycleEventEnabled]) return;
            if ([TDUtils isIAPEvent:record] && ![self isInAppPurchaseEventEnabled]) return;

            if (self.client) {
                if (database && table) {
                    NSError *formatError = nil;
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-z_]{3,255}$" options:0 error:&formatError];
                    if (!([regex firstMatchInString:database options:0 range:NSMakeRange(0, [database length])] &&
                          [regex firstMatchInString:table    options:0 range:NSMakeRange(0, [table length])])) {
                        NSString *errMsg = [NSString stringWithFormat:@"database and table need to be consist of lower letters, numbers or '_': database=%@, table=%@", database, table];
                        KCLog(@"%@", errMsg);
                        error(ERROR_CODE_INVALID_PARAM, errMsg);
                    }
                    else {
                        NSString *tag = [NSString stringWithFormat:@"%@.%@", database, table];
                        NSDictionary *enrichedRecord = [self enrichEventRecord:record database:database table:table];
                        [self.client addEventWithCallbacks:enrichedRecord
                                         toEventCollection:tag
                                                 onSuccess:success
                                                   onError:error];
                        event = [enrichedRecord copy];
                        return;
                    }
                }
                else {
                    NSString *errMsg = [NSString stringWithFormat:@"database or table is nil: database=%@, table=%@", database, table];
                    KCLog(@"%@", errMsg);
                    error(ERROR_CODE_INVALID_PARAM, errMsg);
                    return;
                }
            }
            else {
                NSString *errMsg = @"ERROR: Unable to add event. TreasureData's client is nil.";
                NSLog(@"%@", errMsg);
                error(ERROR_CODE_INVALID_PARAM, errMsg);
            }
            return;
        }
        @catch (NSException *exception) {
            NSLog(@"ERROR: Unexpected exception when adding event: %@", exception);
            error(@"unknown_error", exception.reason);
        }
    });

    return event;
}

- (NSDictionary *)enrichEventRecord:(NSDictionary *)origRecord database:(NSString *)database table:(NSString *)table {
    NSDictionary *enrichedRecord = [self prependDefaultValues:origRecord database:database table:table];
    
    enrichedRecord = [TDUtils stripNonEventData:enrichedRecord];
    
    if (self.autoAppendLocalTimestampColumn != nil) {
        enrichedRecord = [self appendLocalTimestamp:enrichedRecord];
    }
    if (self.autoAppendUniqId) {
        enrichedRecord = [self appendUniqId:enrichedRecord];
    }
    if (self.autoAppendRecordUUIDColumn) {
        enrichedRecord = [self appendRecordUUID:enrichedRecord];
    }
    if (self.autoAppendModelInformation) {
        enrichedRecord = [self appendModelInformation:enrichedRecord];
    }
    if (session || self.sessionId) {
        enrichedRecord = [self appendSessionId:enrichedRecord];
    }
    if (self.autoAppendAppInformation) {
        enrichedRecord = [self appendAppInformation:enrichedRecord];
    }
    if (self.autoAppendLocaleInformation) {
        enrichedRecord = [self appendLocaleInformation:enrichedRecord];
    }
    if (self.autoAppendAdvertisingIdColumn) {
        enrichedRecord = [self appendAdvertisingIdentifier:enrichedRecord];
    }
    return enrichedRecord;
}

- (NSDictionary *)prependDefaultValues:(NSDictionary *)origRecord database:(NSString *)database table:(NSString *)table {
    if (_defaultValues == nil) return origRecord;
    NSMutableDictionary *record = [NSMutableDictionary new];

    NSString *anyTableOrDatabaseKey = @".";
    [record addEntriesFromDictionary:[_defaultValues objectForKey:anyTableOrDatabaseKey]];
    NSString *anyTableKey = [NSString stringWithFormat:@"%@.", database];
    [record addEntriesFromDictionary:[_defaultValues objectForKey:anyTableKey]];
    NSString *anyDatabaseKey = [NSString stringWithFormat:@".%@", table];
    [record addEntriesFromDictionary:[_defaultValues objectForKey:anyDatabaseKey]];
    NSString *tableKey = [NSString stringWithFormat:@"%@.%@", database, table];
    [record addEntriesFromDictionary:[_defaultValues objectForKey:tableKey]];
    
    [record addEntriesFromDictionary:origRecord];
    return record;
}

- (NSString *)getUUID {
    if (_UUID == nil) {
        _UUID = [[NSUserDefaults standardUserDefaults] stringForKey:storageKeyOfUuid];
    }
    if (_UUID == nil) {
        _UUID = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
    }
    return _UUID;
}

- (NSDictionary*)appendLocalTimestamp:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    NSDate *now = [NSDate date];
    NSNumber *timestamp = [NSNumber numberWithInt:(int) now.timeIntervalSince1970];
    [record setValue:timestamp forKey:self.autoAppendLocalTimestampColumn];
    return record;
}

- (NSDictionary*)appendUniqId:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    [record setValue:[self getUUID] forKey:keyOfUuid];
    return record;
}

- (NSDictionary*)appendRecordUUID:(NSDictionary *)origRecord {
    NSString *uuid;
    if (!NSClassFromString(@"NSUUID")) {
        uuid = @"";
    }
    else {
        uuid = [[NSUUID UUID] UUIDString];
    }
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    [record setValue:uuid forKey:self.autoAppendRecordUUIDColumn];
    return record;
}

- (NSDictionary*)appendModelInformation:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    UIDevice *dev = [UIDevice currentDevice];
    // [record setValue:@"" forKey:key_of_board];
    // [record setValue:@"" forKey:key_of_brand];
    [record setValue:dev.model forKey:keyOfDevice];
    // [record setValue:@"" forKey:key_of_display];
    [record setValue:dev.model forKey:keyOfModel];
    [record setValue:dev.systemVersion forKey:keyOfOsVer];
#if TARGET_OS_TV
    [record setValue:@"tvOS" forKey:keyOfOsType];
#else
    [record setValue:@"iOS" forKey:keyOfOsType];
#endif
    return record;
}

- (NSDictionary*)appendAppInformation:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    NSString *appVersion = [self getAppVersion];
    NSString *buildNumber = [self getBuildNumber];
    [record setValue:appVersion forKey:keyOfAppVer];
    [record setValue:buildNumber forKey:keyOfAppVerNum];
    return record;
}

- (NSString*)getAppVersion {
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    return [infoDict objectForKey:@"CFBundleShortVersionString"];
}

- (NSString*)getBuildNumber {
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    return [infoDict objectForKey:@"CFBundleVersion"];
}

- (NSString *)getTrackedAppVersion {
    return [[NSUserDefaults standardUserDefaults] stringForKey:TD_USER_DEFAULTS_KEY_TRACKED_APP_VERSION];
}

- (NSString *)getTrackedBuildNumber {
    return [[NSUserDefaults standardUserDefaults] stringForKey:TD_USER_DEFAULTS_KEY_TRACKED_APP_BUILD];
}


- (NSDictionary*)appendLocaleInformation:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    NSLocale *locale = [NSLocale currentLocale];
    [record setValue:[locale objectForKey: NSLocaleCountryCode] forKey:keyOfLocaleCountry];
    [record setValue:[locale objectForKey: NSLocaleLanguageCode] forKey:keyOfLocaleLang];
    return record;
}

- (NSDictionary*)appendAdvertisingIdentifier:(NSDictionary *)origRecord {
    NSString *advertisingIdentifier = nil;
    Class identifierManager = NSClassFromString(@"ASIdentifierManager");
    if (identifierManager) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        IMP sharedManagerMethod = [identifierManager methodForSelector:sharedManagerSelector];
        id sharedManager = ((id (*)(id, SEL)) sharedManagerMethod)(identifierManager, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        IMP advertisingIdentifierMethod = [sharedManager methodForSelector:advertisingIdentifierSelector];
        NSUUID *uuid = ((NSUUID * (*)(id, SEL)) advertisingIdentifierMethod)(sharedManager, advertisingIdentifierSelector);
        advertisingIdentifier = [uuid UUIDString];
    }
    
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    [record setValue:advertisingIdentifier forKey:self.autoAppendAdvertisingIdColumn];
    return record;
}

- (NSDictionary*)appendSessionId:(NSDictionary *)origRecord {
    if (session && self.sessionId) {
        KCLog(@"instance method TreasureData#startSession(String) and static method TreasureData.startSession() are both enabled, but the instance method will be ignored.");
    }

    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    if (session) {
        NSString *sessionId = [session getId];
        if (sessionId) {
            [record setValue:sessionId forKey:keyOfSessionId];
        }
    }
    else {
        [record setValue:self.sessionId forKey:keyOfSessionId];
    }
    return record;
}

- (void)uploadWithBlock:(void (^)(void))block {
    [self uploadEventsWithBlock:block];
}

- (void)uploadEventsWithBlock:(void (^)(void))block {
    if (self.client) {
        [self.client uploadWithFinishedBlock:block];
    }
    else {
        NSLog(@"ERROR: The TreasureData's client is nil");
    }
}

- (void)uploadEventsWithCallback:(void (^)(void))onSuccess onError:(void (^)(NSString*, NSString*))onError {
    if (self.client) {
        [self.client __enableEventCompression:isEventCompressionEnabled];
        [self.client uploadWithCallbacks:onSuccess onError:onError];
    }
    else {
        NSString *errMsg = @"ERROR: Unable to upload events. TreasureData's client is nil.";
        NSLog(@"%@", errMsg);
        if (onError) {
            onError(ERROR_CODE_INIT_ERROR, errMsg);
        }
    }
}

- (void)uploadEvents {
    [self uploadEventsWithCallback:nil onError:nil];
}

- (void)setApiEndpoint:(NSString*)endpoint {
    self.client.apiEndpoint = endpoint;
}

- (void)disableAutoAppendUniqId {
    self.autoAppendUniqId = false;
}

// TODO: should the below methods be changed to flag properties?

- (void)enableAutoAppendUniqId {
    self.autoAppendUniqId = true;
}

- (void)disableAutoAppendModelInformation {
    self.autoAppendModelInformation = false;
}

- (void)enableAutoAppendModelInformation {
    self.autoAppendModelInformation = true;
}

- (void)enableAutoAppendAppInformation {
    self.autoAppendAppInformation = true;
}

- (void)disableAutoAppendAppInformation {
    self.autoAppendAppInformation = false;
}

- (void)enableAutoAppendLocaleInformation {
    self.autoAppendLocaleInformation = true;
}

- (void)disableAutoAppendLocaleInformation {
    self.autoAppendLocaleInformation = false;
}

- (void)disableRetryUploading {
    self.client.enableRetryUploading = false;
}

- (void)enableRetryUploading {
    self.client.enableRetryUploading = true;
}

// TODO: consider whether it is necessary for `isFirstRun` (and `clearFirstRun`) to be exposed

- (BOOL)isFirstRun {
    NSInteger state = [[NSUserDefaults standardUserDefaults] integerForKey:storageKeyOfFirstRun];
    return state == 0;
}

- (void)clearFirstRun {
    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:storageKeyOfFirstRun];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)initializeFirstRun {
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:storageKeyOfFirstRun];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)startSession:(NSString*)table {
    [self startSession:table database:self.defaultDatabase];
}

- (void)startSession:(NSString*)table database:(NSString*)database {
    self.sessionId = [[NSUUID UUID] UUIDString];
    [self addEvent:@{keyOfSessionEvent: sessionEventStart} database:database table:table];
}

- (void)endSession:(NSString*)table {
    [self endSession:table database:self.defaultDatabase];
}

- (void)endSession:(NSString*)table database:(NSString*)database {
    [self addEvent:@{keyOfSessionEvent: sessionEventEnd} database:database table:table];
    self.sessionId = nil;
}

- (NSString *)getSessionId {
    return self.sessionId;
}

+ (void)startSession {
    if (!session) {
        session = [Session new];
        if (sessionTimeoutMilli > 0) {
            session.sessionPendingMillis = sessionTimeoutMilli;
        }
    }
    [session start];
}

+ (void)endSession {
    if (session) {
        [session finish];
    }
}

+ (NSString*)getSessionId {
    if (!session) {
        return nil;
    }
    return [session getId];
}

+ (void)resetSessionId {
    [session resetId];
}

+ (void)setSessionTimeoutMilli:(long)to {
    sessionTimeoutMilli = to;
}

- (void)enableAutoAppendLocalTimestamp {
    self.autoAppendLocalTimestampColumn = keyOfLocalTimestamp;
}

- (void)enableAutoAppendLocalTimestamp:(NSString *)columnName {
    if (!columnName) {
        KCLog(@"WARN: the specified columnName for local timestamp is nil. This call is noop");
        return;
    }
    self.autoAppendLocalTimestampColumn = columnName;
}

- (void)disableAutoAppendLocalTimestamp {
    self.autoAppendLocalTimestampColumn = nil;
}

- (void)enableAutoAppendRecordUUID {
    self.autoAppendRecordUUIDColumn = @"record_uuid";
}

- (void)enableAutoAppendRecordUUID:(NSString *)columnName {
    if (!columnName) {
        KCLog(@"WARN: the specified columnName for record UUID is nil; auto appending record UUID won't be enabled.");
        // FIXME:
        // A more sensible behaviour is using "record_uuid" as the default column name,
        // but it is a behaviour change, will postpone it for a later release.
        return;
    }
    self.autoAppendRecordUUIDColumn = columnName;
}

- (void)disableAutoAppendRecordUUID {
    self.autoAppendRecordUUIDColumn = nil;
}

- (void)enableAutoAppendAdvertisingIdentifier {
    [self enableAutoAppendAdvertisingIdentifier: keyOfAdvertisingIdentifier];
}

- (void)enableAutoAppendAdvertisingIdentifier:(NSString *)columnName {
    Class identifierManager = NSClassFromString(@"ASIdentifierManager");
    if (!identifierManager) {
        NSLog(@"ERROR: You are attempting to enable auto append Advertising Identifer but ASIdentifierManager class is not detected. To use this feature, you must link AdSupport framework in your project");
    } else {
        self.autoAppendAdvertisingIdColumn = columnName;
    }
}

- (void)disableAutoAppendAdvertisingIdentifier {
    self.autoAppendAdvertisingIdColumn = nil;
}

- (void)enableAutoTrackingIP {
    self.client.enableTrackingIP = true;
}

- (void)disableAutoTrackingIP {
    self.client.enableTrackingIP = false;
}

+ (instancetype)sharedInstance {
    NSAssert(sharedInstance, @"%@ sharedInstance is called before [TreasureData initializeWithApiKey:]", self);
    return sharedInstance;
}

+ (void)initializeWithApiKey:(NSString *)apiKey {
    [self initializeWithApiKey:apiKey apiEndpoint:defaultApiEndpoint];
}

+ (void)initializeWithApiKey:(NSString *)apiKey apiEndpoint:(NSString *)apiEndpoint{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithApiKey:apiKey apiEndpoint:apiEndpoint];
    });
}

+ (void)initializeEncryptionKey:(NSString*)encryptionKey {
    [TDClient initializeEncryptionKey:encryptionKey];
}

+ (void)disableEventCompression {
    isEventCompressionEnabled = false;
}

+ (void)enableEventCompression {
    isEventCompressionEnabled = true;
}

+ (void)disableLogging {
    [KeenClient disableLogging];
}

+ (void)enableLogging {
    [KeenClient enableLogging];
}

+ (void)disableTraceLogging {
    isTraceLoggingEnabled = false;
}

// FIXME: what is the real usage for this?
+ (void)enableTraceLogging {
    isTraceLoggingEnabled = true;
}

#pragma mark -

- (void)observeLifecycleEvents {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleAppDidLaunching:) name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
}

- (void)handleAppDidLaunching:(NSNotification *)notification
{
    if ([self isAppLifecycleEventEnabled]) {
        NSString *targetDatabase = [TDUtils requireNonBlank:self.defaultDatabase
                                            defaultValue:TD_DEFAULT_DATABASE
                                                 message:[NSString
                                                          stringWithFormat:@"WARN: defaultDatabase was not set. \"%@\" will be used as the target database for app lifecycle events.",
                                                          TD_DEFAULT_DATABASE]];
        NSString *targetTable = [TDUtils requireNonBlank:self.defaultTable
                                             defaultValue:TD_DEFAULT_TABLE
                                                  message:[NSString
                                                           stringWithFormat:@"WARN: defaultTable was not set. \"%@\" will be used as the target table for app lifecycle events.",
                                                           TD_DEFAULT_TABLE]];
        NSString *currentVersion = [self getAppVersion];
        NSString *currentBuild = [self getBuildNumber];
        NSString *previousVersion = [self getTrackedAppVersion];
        NSString *previousBuild = [self getTrackedBuildNumber];

        // For lifecycle event, application's version and build number is always attached regardless of the autoAppendAppInformation setting
        if (!previousVersion) {
            [self addEvent:[TDUtils markAsAppLifecycleEvent:
                            @{TD_COLUMN_EVENT: TD_EVENT_APP_INSTALLED,
                              keyOfAppVer: currentVersion,
                              keyOfAppVerNum: currentBuild}]
                  database:targetDatabase
                     table:targetTable];
        } else if (![previousVersion isEqualToString:currentVersion]) {
            [self addEvent:[TDUtils markAsAppLifecycleEvent:
                            @{TD_COLUMN_EVENT: TD_EVENT_APP_UPDATED,
                              keyOfPreviousAppVer: previousVersion,
                              keyOfPreviousAppVerNum: previousBuild,
                              keyOfAppVer: currentVersion,
                              keyOfAppVerNum: currentBuild}]
                  database:targetDatabase
                     table:targetTable];
        }
        [self addEvent:[TDUtils markAsAppLifecycleEvent:
                        @{TD_COLUMN_EVENT: TD_EVENT_APP_OPENED,
                          keyOfAppVer: currentVersion,
                          keyOfAppVerNum: currentBuild}]
              database:targetDatabase
                 table:targetTable];

        [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:TD_USER_DEFAULTS_KEY_TRACKED_APP_VERSION];
        [[NSUserDefaults standardUserDefaults] setObject:currentBuild forKey:TD_USER_DEFAULTS_KEY_TRACKED_APP_BUILD];
    }
}

#pragma mark - GDPR Compliance

- (void)enableCustomEvent {
    self.customEventEnabled = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED];
}

- (void)disableCustomEvent {
    self.customEventEnabled = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED];
}

- (void)enableAppLifecycleEvent {
    self.appLifecycleEventEnabled = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TD_USER_DEFAULTS_KEY_APP_LIFECYCLE_EVENT_ENABLED];
}

- (void)disableAppLifecycleEvent {
    self.appLifecycleEventEnabled = NO;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:TD_USER_DEFAULTS_KEY_APP_LIFECYCLE_EVENT_ENABLED];
}

- (void)enableInAppPurchaseEvent {
    if ([TDUtils isStoreKitAvailable]) {
        self.inAppPurchaseEnabled = YES;
        if (!_iapObserver) {
            _iapObserver = [[TDIAPObserver alloc] initWithTD:self];
        }
    } else {
        NSLog(@"WARN: Unable to enable IAP tracking as StoreKit is not available for this application!");
    }
}

- (void)disableInAppPurchaseEvent {
    self.inAppPurchaseEnabled = NO;
    _iapObserver = nil;
}

- (void)resetUniqId {
    _UUID = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
    NSString *eventTypeColumn = [TDUtils isRunningWithUnity] ? TD_COLUMN_UNITY_EVENT : TD_COLUMN_EVENT;
    [self addEvent:[TDUtils markAsAuditEvent:@{eventTypeColumn: TD_EVENT_AUDIT_RESET_UUID}]
             table: [TDUtils requireNonBlank:self.defaultTable
                                defaultValue:TD_DEFAULT_TABLE
                                     message:[NSString
                                              stringWithFormat:@"WARN: defaultTable was not set. \"%@\" will be used as the target table.",
                                              TD_DEFAULT_TABLE]]];
    _UUID = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
}

#pragma mark - Personalization API

- (void)fetchUserSegments: (nonnull NSArray<NSString *> *)audienceTokens
                     keys: (nonnull NSDictionary<NSString *, id> *)keys
                  options: (nullable NSDictionary<TDRequestOptionsKey, id> *)options
        completionHandler: (void (^_Nonnull)(NSArray* _Nullable jsonResponse, NSError* _Nullable error)) handler {
    // Construct url
    NSString *cdpEndpoint = self.cdpEndpoint ? self.cdpEndpoint : defaultCdpEndpoint;
    NSMutableArray *encodedAudienceTokens = [[NSMutableArray alloc] init];
    for (NSString *token in audienceTokens) {
        [encodedAudienceTokens addObject:urlEncode(token)];
    }
    NSString *audienceString = [NSString
                                stringWithFormat:@"&token=%@",
                                [encodedAudienceTokens componentsJoinedByString: @","]];
    NSMutableString *keyString = [[NSMutableString alloc] initWithString: @""];
    for (NSString *key in keys) {
        [keyString appendFormat:@"&key.%@=%@", urlEncode(key), urlEncode(keys[key])];
    }
    NSMutableString *urlString = [NSMutableString stringWithString:cdpEndpoint];
    [urlString appendString:@"/cdp/lookup/collect/segments?version=2"];
    [urlString appendString:audienceString];
    [urlString appendString:keyString];
    NSURL *url = [NSURL URLWithString:urlString];

    // Construct request
    NSNumber *timeoutNumber = (NSNumber *)options[TDRequestOptionsTimeoutIntervalKey];
    NSTimeInterval timeout = timeoutNumber ? [timeoutNumber doubleValue] : 60;
    NSNumber *cachePolicyNumber = (NSNumber *)options[TDRequestOptionsCachePolicyKey];
    NSURLRequestCachePolicy cachePolicy = cachePolicyNumber ? [cachePolicyNumber unsignedIntegerValue] : NSURLRequestUseProtocolCachePolicy;
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url
                                                cachePolicy:cachePolicy
                                            timeoutInterval:timeout];
    
    // Call api
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable connectionError) {
        NSLog(@"urlconn response %@, data %@, connectionError %@", response, data, connectionError);
        if (connectionError) {
            handler(nil, connectionError);
        } else {
            NSError *jsonError = nil;
            id jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                              options:kNilOptions
                                                                error:&jsonError];
            if ([jsonResponse isKindOfClass: [NSArray class]]) {
                // Successful case
                handler((NSArray *)jsonResponse, jsonError);
            } else if ([jsonResponse isKindOfClass: [NSDictionary class]] && ((NSDictionary *)jsonResponse)[@"error"] != nil) {
                // Error returned in response
                NSDictionary *errorResponse = (NSDictionary *)jsonResponse;
                NSMutableDictionary *userInfo = [NSMutableDictionary new];
                if (errorResponse[@"error"]) {
                    userInfo[NSLocalizedDescriptionKey] = errorResponse[@"error"];
                }
                if (errorResponse[@"message"]) {
                    userInfo[NSLocalizedFailureReasonErrorKey] = errorResponse[@"message"];
                }
                NSInteger code = [(NSNumber *)errorResponse[@"status"] integerValue];
                NSError *serverError = [NSError errorWithDomain:TreasureDataErrorDomain code:code userInfo: userInfo];
                handler(nil, serverError);
            } else {
                // Unrecognizable response format returned
                NSDictionary *userInfo = @{
                   NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid reponse format", nil),
                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Server returned unrecognizable response format", nil)
                };
                NSError *unrecogizaleResponseFormatError = [NSError errorWithDomain:TreasureDataErrorDomain code:-1 userInfo:userInfo];
                handler(nil, unrecogizaleResponseFormatError);
            }
        }
    }];
    [dataTask resume];
}

#pragma mark - Default values

-(NSString *)defaultValueTableKeyForDatabase:(nullable NSString *)database table:(nullable NSString *)table {
    NSString *_database = database == nil ? @"" : database;
    NSString *_table = table == nil ? @"" : table;
    return [NSString stringWithFormat:@"%@.%@", _database, _table];
}

- (void)setDefaultValue:(nonnull id)value forKey:(nonnull NSString *)key database:(nullable NSString *)database table:(nullable NSString *)table {
    if (_defaultValues == nil) _defaultValues = [NSMutableDictionary new];
    NSString *tableKey = [self defaultValueTableKeyForDatabase:database table:table];
    NSDictionary *tableDictionary = [_defaultValues objectForKey:tableKey];
    NSMutableDictionary *mutableTableDictionary = tableDictionary == nil ? [NSMutableDictionary dictionary] : [NSMutableDictionary dictionaryWithDictionary:tableDictionary];
    
    [mutableTableDictionary setObject:value forKey:key];
    [_defaultValues setObject:mutableTableDictionary forKey:tableKey];
}

- (nullable id)defaultValueForKey:(nonnull NSString*)key database:(nullable NSString *)database table:(nullable NSString *)table {
    NSString *tableKey = [self defaultValueTableKeyForDatabase:database table:table];
    NSDictionary *tableDictionary = [_defaultValues objectForKey:tableKey];
    return [tableDictionary objectForKey:key];
}

- (void)removeDefaultValueForKey:(nonnull NSString *)key database:(nullable NSString *)database table:(nullable NSString *)table {
    NSString *tableKey = [self defaultValueTableKeyForDatabase:database table:table];
    NSDictionary *tableDictionary = [_defaultValues objectForKey:tableKey];
    if (tableDictionary == nil) return;
    NSMutableDictionary *mutableTableDictionary = [NSMutableDictionary dictionaryWithDictionary:tableDictionary];
    
    [mutableTableDictionary removeObjectForKey:key];
    [_defaultValues setObject:mutableTableDictionary forKey:tableKey];
}

#pragma mark - Exposed for testing

+ (void)resetSession {
    session = nil;
}

- (TDIAPObserver *)iapObserver {
    return _iapObserver;
}

@end

