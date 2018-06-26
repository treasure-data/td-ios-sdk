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
#import "math.h"
#import "TDClient.h"
#import "Session.h"
#import "TDUtils.h"
#import "Constants.h"

static bool isTraceLoggingEnabled = false;
static bool isEventCompressionEnabled = true;
static TreasureData *sharedInstance = nil;
static NSString *tableNamePattern = @"[^0-9a-z_]";
static NSString *defaultApiEndpoint = nil;
static NSString *storageKeyOfUuid = @"td_sdk_uuid";
static NSString *storageKeyOfFirstRun = @"td_sdk_first_run";
static NSString *keyOfUuid = @"td_uuid";
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
static NSString *keyOfServerSideUploadTimestamp = @"#SSUT";
static NSString *osType = @"iOS";
static NSString *sessionEventStart = @"start";
static NSString *sessionEventEnd = @"end";
static Session *session = nil;
static long sessionTimeoutMilli = -1;

@interface TreasureData ()

@property BOOL autoAppendUniqId;
@property BOOL autoAppendModelInformation;
@property BOOL autoAppendAppInformation;
@property BOOL autoAppendLocaleInformation;
@property NSString *sessionId;
@property BOOL serverSideUploadTimestamp;
@property NSString *serverSideUploadTimestampColumn;
@property NSString *autoAppendRecordUUIDColumn;

@property (nonatomic, assign, getter=isCustomEventEnabled) BOOL customEventEnabled;
@property (nonatomic, assign, getter=isAppLifecycleEventEnabled) BOOL appLifecycleEventEnabled;

@end

@implementation TreasureData {
    NSString *_UUID;
}

static NSString *const DefaultTreasureDataDatabase = @"td";
static NSString *const DefaultTreasureDataTable = @"td_ios";

- (id)initWithApiKey:(NSString *)apiKey {
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

        if ([[NSUserDefaults standardUserDefaults] objectForKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED] != nil) {
            self.customEventEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED];
        } else {
            // Unless being explicitly disabled, custom events are allowed
            self.customEventEnabled = YES;
        }

        // Unlike custom events, app lifecycle events must be explicitly enabled
        self.appLifecycleEventEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:TD_USER_DEFAULTS_KEY_APP_LIFECYCLE_EVENT_ENABLED];

        NSString *endpoint = defaultApiEndpoint ? defaultApiEndpoint : @"https://in.treasuredata.com";
        self.client = [[TDClient alloc] initWithApiKey:apiKey apiEndpoint:endpoint];
        if (self.client) {

        } else {
            KCLog(@"Failed to initialize client");
        }
        [self observeLifecycleEvents];
    }
    return self;
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

- (NSDictionary *)addEventWithCallback:(NSDictionary *)record
                              database:(NSString *)database
                                 table:(NSString *)table
                             onSuccess:(SuccessHander)onSuccess
                               onError:(ErrorHandler)onError {
    if ([TDUtils isCustomEvent:record] && ![self isCustomEventEnabled]) {
        if (onError) {
            onError(TD_ERROR_CUSTOM_EVENT_DISABLED,
                    @"You configured to deny tracking of custom events. This is a persistent setting, it will unharmfully drop the any custom events called through `addEvent...` methods family.");
        }
        return nil;
    }
    // App Lifecyle events denial is silent
    if ([TDUtils isAppLifecycleEvent:record] && ![self isAppLifecycleEventEnabled]) {
        return nil;
    }
    record = [TDUtils stripNonEventData:record];
    if (self.client) {
        if (database && table) {
            NSError *error = nil;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-z_]{3,255}$" options:0 error:&error];
            if (!([regex firstMatchInString:database options:0 range:NSMakeRange(0, [database length])] &&
                  [regex firstMatchInString:table    options:0 range:NSMakeRange(0, [table length])])) {
                NSString *errMsg = [NSString stringWithFormat:@"database and table need to be consist of lower letters, numbers or '_': database=%@, table=%@", database, table];
                KCLog(@"%@", errMsg);
                if (onError) {
                    onError(ERROR_CODE_INVALID_PARAM, errMsg);
                }
            }
            else {
                if (self.autoAppendUniqId) {
                    record = [self appendUniqId:record];
                }
                if (self.autoAppendRecordUUIDColumn) {
                    record = [self appendRecordUUID:record];
                }
                if (self.autoAppendModelInformation) {
                    record = [self appendModelInformation:record];
                }
                if (session || self.sessionId) {
                    record = [self appendSessionId:record];
                }
                if (self.serverSideUploadTimestamp) {
                    record = [self appendServerSideUploadTimestamp:record];
                }
                if (self.autoAppendAppInformation) {
                    record = [self appendAppInformation:record];
                }
                if (self.autoAppendLocaleInformation) {
                    record = [self appendLocaleInformation:record];
                }

                NSString *tag = [NSString stringWithFormat:@"%@.%@", database, table];
                [self.client addEventWithCallbacks:record toEventCollection:tag onSuccess:onSuccess onError:onError];
                return [NSDictionary dictionaryWithDictionary:record];
            }
        }
        else {
            NSString *errMsg = [NSString stringWithFormat:@"database or table is nil: database=%@, table=%@", database, table];
            KCLog(@"%@", errMsg);
            if (onError) {
                onError(ERROR_CODE_INVALID_PARAM, errMsg);
            }
            return nil;
        }
    }
    else {
        NSString *errMsg = @"Client is nil";
        KCLog(@"%@", errMsg);
        if (onError) {
            onError(ERROR_CODE_INIT_ERROR, errMsg);
        }
    }
    return nil;
}

- (NSDictionary *)addEventWithCallback:(NSDictionary *)record table:(NSString *)table onSuccess:(void (^)(void))onSuccess onError:(void (^)(NSString*, NSString*))onError {
    return [self addEventWithCallback:record database:self.defaultDatabase table:table onSuccess:onSuccess onError:onError];
}

- (NSString*)getUUID {
    if (_UUID == nil) {
        _UUID = [[NSUserDefaults standardUserDefaults] stringForKey:storageKeyOfUuid];
    }
    if (_UUID == nil) {
        _UUID = [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
    }
    return _UUID;
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
    [record setValue:osType forKey:keyOfOsType];
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

- (NSDictionary*)appendSessionId:(NSDictionary *)origRecord {
    if (session && self.sessionId) {
        NSLog(@"instance method TreasureData#startSession(String) and static method TreasureData.startSession() are both enabled, but the instance method will be ignored.");
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

- (NSDictionary*)appendServerSideUploadTimestamp:(NSDictionary *)origRecord {
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:origRecord];
    if (self.serverSideUploadTimestampColumn) {
        [record setValue:self.serverSideUploadTimestampColumn forKey:keyOfServerSideUploadTimestamp];
    }
    else {
        [record setValue:@true forKey:keyOfServerSideUploadTimestamp];
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
        KCLog(@"Client is nil");
    }
}

- (void)uploadEventsWithCallback:(void (^)(void))onSuccess onError:(void (^)(NSString*, NSString*))onError {
    if (self.client) {
        self.client.enableEventCompression = isEventCompressionEnabled;
        [self.client uploadWithCallbacks:onSuccess onError:onError];
    }
    else {
        NSString *errMsg = @"Client is nil";
        KCLog(@"%@", errMsg);
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

// Only for test
+ (void)resetSession {
    session = nil;
}

+ (void)setSessionTimeoutMilli:(long)to {
    sessionTimeoutMilli = to;
}

- (void)enableServerSideUploadTimestamp {
    self.serverSideUploadTimestamp = TRUE;
    self.serverSideUploadTimestampColumn = nil;
}

- (void)enableServerSideUploadTimestamp: (NSString*)columnName {
    if (!columnName) {
        NSLog(@"columnName shouldn't be nil");
        return;
    }
    self.serverSideUploadTimestamp = TRUE;
    self.serverSideUploadTimestampColumn = columnName;
}

- (void)disableServerSideUploadTimestamp {
    self.serverSideUploadTimestamp = FALSE;
    self.serverSideUploadTimestampColumn = nil;
}

- (void)enableAutoAppendRecordUUID {
    self.autoAppendRecordUUIDColumn = @"record_uuid";
}

- (void)enableAutoAppendRecordUUID: (NSString*)columnName {
    if (!columnName) {
        NSLog(@"columnName shouldn't be nil");
        return;
    }
    self.autoAppendRecordUUIDColumn = columnName;
}

- (void)disableAutoAppendRecordUUID {
    self.autoAppendRecordUUIDColumn = nil;
}

+ (void)initializeWithApiKey:(NSString *)apiKey {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithApiKey:apiKey];
    });
}

+ (void)initializeEncryptionKey:(NSString*)encryptionKey {
    [TDClient initializeEncryptionKey:encryptionKey];
}


+ (instancetype)sharedInstance {
    NSAssert(sharedInstance, @"%@ sharedInstance called before withSecret", self);
    return sharedInstance;
}

+ (void)initializeApiEndpoint:(NSString *)apiEndpoint {
    defaultApiEndpoint = apiEndpoint;
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
                                            defaultValue:DefaultTreasureDataDatabase
                                                 message:[NSString
                                                          stringWithFormat:@"WARN: defaultDatabase was not set. \"%@\" will be used as the target database.",
                                                          DefaultTreasureDataDatabase]];
        NSString *targetTable = [TDUtils requireNonBlank:self.defaultTable
                                             defaultValue:DefaultTreasureDataTable
                                                  message:[NSString
                                                           stringWithFormat:@"WARN: defaultTable was not set. \"%@\" will be used as the target table.",
                                                           DefaultTreasureDataTable]];
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


#pragma mark - GDPR Compliance (Right To Be Forgotten)

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

- (void)resetUniqId {
    _UUID = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
    NSString *eventTypeColumn = [TDUtils isRunningWithUnity] ? TD_COLUMN_UNITY_EVENT : TD_COLUMN_EVENT;
    [self addEvent:[TDUtils markAsAuditEvent:@{eventTypeColumn: TD_EVENT_AUDIT_RESET_UUID}]
             table: [TDUtils requireNonBlank:self.defaultTable
                                defaultValue:DefaultTreasureDataTable
                                     message:[NSString
                                              stringWithFormat:@"WARN: defaultTable was not set. \"%@\" will be used as the target table.",
                                              DefaultTreasureDataTable]]];
    _UUID = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:_UUID forKey:storageKeyOfUuid];
}

@end

