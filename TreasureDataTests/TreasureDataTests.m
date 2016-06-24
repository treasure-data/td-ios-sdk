//
//  TreasureDataTests.m
//  TreasureDataTests
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TreasureData.h"
#import "TDClient.h"

static NSString *END_POINT = @"http://localhost";

@interface MyTDClient : TDClient
@end

@implementation MyTDClient
@end

@interface MySessionDataTask : NSURLSessionDataTask
@end

@implementation MySessionDataTask
- (void)resume {}
@end

@interface MySession : NSURLSession
@property NSURLRequest *requestData;
@property NSData *expectedResponseBody;
@property NSURLResponse *expectedResponse;
@property int sendRequestCount;
@end

@implementation MySession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler {
    self.sendRequestCount++;
    self.requestData = request;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:0.2];
        completionHandler(self.expectedResponseBody, self.expectedResponse, nil);
    });
    return (NSURLSessionDataTask*)[[MySessionDataTask alloc] init];
}
@end

@interface MyTreasureData : TreasureData
@end

@implementation MyTreasureData
- (id)initWithApiKey:(NSString *)apiKey {
    self = [super initWithApiKey:apiKey];
    MyTDClient *myClient = [[MyTDClient alloc] initWithApiKey:apiKey apiEndpoint:END_POINT];
    self.client = myClient;
    MySession *session = [[MySession alloc] init];
    self.client.session = session;
    return self;
}

- (NSString*)getAppVersion {
    return @"1.2.3";
}

- (NSString*)getBuildNumber {
    return @"42";
}
@end

@interface TreasureDataTests : XCTestCase
@property bool isFinished;
@property MyTreasureData* td;
@property MyTDClient *client;
@property MySession *session;
@end

@implementation TreasureDataTests

- (void)setUp
{
    [self initializeTD];
    [TreasureData setSessionTimeoutMilli:-1];
    [super setUp];
}

- (void)initializeTD {
    self.td = [[MyTreasureData alloc] initWithApiKey:@"dummy_apikey"];
    [self.td initializeFirstRun];
    self.client = (MyTDClient*)self.td.client;
    self.session = (MySession*)self.td.client.session;
    [[MyTDClient getEventStore] deleteAllEvents];
    [MyTreasureData disableEventCompression];
}

- (void)tearDown
{
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    } while (!self.isFinished);
    [super tearDown];
}

- (void)setupDefaultExpectedResponse:(NSInteger)statusCode {
    NSHTTPURLResponse *expectedResponse =
    [[NSHTTPURLResponse alloc] initWithURL:[[NSURL alloc] initWithString:@"http://localhost/dummy"]
                                statusCode:statusCode HTTPVersion:@"1.1" headerFields:nil];
    self.session.expectedResponse = expectedResponse;
}

- (void)setupDefaultExpectedResponse {
    [self setupDefaultExpectedResponse:200];
}

- (void)setupDefaultExpectedResponseBody:(NSDictionary*)dict {
    NSError *error = [NSError alloc];
    NSData *expectedResponseBody = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    self.session.expectedResponseBody = expectedResponseBody;
}

- (void)assertRequest:(void(^)(NSDictionary*))assertion {
    NSString *url = [self.session.requestData.URL absoluteString];
    XCTAssertEqualObjects(@"http://localhost/ios/v3/event", url);
    NSError *error = [NSError alloc];
    NSDictionary *ev = [NSJSONSerialization JSONObjectWithData:self.session.requestData.HTTPBody options:0 error:&error];
    assertion(ev);
}

- (void)baseTesting:(void(^)())setup onSuccess:(void(^)(void))onSuccess onError:(void(^)(NSString*, NSString*))onError {
    NSString *url = self.client.apiEndpoint;
    XCTAssertEqualObjects(@"http://localhost", url);

    [self setupDefaultExpectedResponse];

    setup();

    [self.td uploadEventsWithCallback:onSuccess onError:onError];
}

- (void)baseTesting:(void(^)())setup assertion:(void(^)(NSDictionary*))assert {
    [self baseTesting:setup onSuccess:^(){
        [self assertRequest:assert];
        self.isFinished = true;
    }
                              onError:^(NSString* ecode, NSString* detail){
                                  XCTAssertTrue(false);
                                  self.isFinished = true;
                              }];
}

- (void)baseTestingError:(void(^)())setup assertion:(void(^)(NSString*))assertion {
    [self baseTesting:setup onSuccess:^(){
        XCTAssertTrue(false);
        self.isFinished = true;
    }
              onError:^(NSString* ecode, NSString* detail){
                  assertion(ecode);
                  self.isFinished = true;
              }];
}

- (void)assertCollectedValueWithKey:(NSArray*)xs
                                key:(NSString*)key
                       expectedVals:(NSArray*)expectedVals
                       expectedKeys:(NSArray*)expectedKeys {
    NSMutableArray* extacted = [[NSMutableArray alloc] init];
    for (NSDictionary* x in xs) {
        NSLog(@"%@", x);
        XCTAssertEqualObjects(
              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
              [expectedKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
        );
        [extacted addObject:[x objectForKey:key]];
    }
    XCTAssertEqualObjects(
                          [expectedVals sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                          [extacted sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
    );
}

- (void)testSingleEvent {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
        assertion:^(NSDictionary *ev){
            XCTAssertEqual(1, self.session.sendRequestCount);
            XCTAssertEqual(1, ev.count);
            NSArray *arr = [ev objectForKey:@"db_.tbl"];
            [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                expectedKeys:@[@"name", @"keen", @"#UUID"]
             ];
        }];
}

- (void)testSingleEventWithServerSideUploadTimestamp {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td enableServerSideUploadTimestamp];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID", @"#SSUT"]
                 ];
            }];
}

- (void)testSingleEventWithDefaultDatabase {
    [self baseTesting:^() {
        [self.td setDefaultDatabase:@"db_"];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                     expectedKeys:@[@"name", @"keen", @"#UUID"]
                 ];
            }];
}

- (void)testMultiEvents {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody:
            @{
              @"db0.tbl0":@[@{@"success":@"true"}, @{@"success":@"true"}],
              @"db1.tbl1":@[@{@"success":@"true"}]
            }
        ];
        [self.td addEvent:@{@"name":@"one"} database:@"db0" table:@"tbl0"];
        [self.td addEvent:@{@"name":@"two"} database:@"db1" table:@"tbl1"];
        [self.td addEvent:@{@"name":@"three"} database:@"db0" table:@"tbl0"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(2, ev.count);
                NSArray *arr = [ev objectForKey:@"db0.tbl0"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"one", @"three"]
                     expectedKeys:@[@"name", @"keen", @"#UUID"]
                 ];
                arr = [ev objectForKey:@"db1.tbl1"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"two"]
                     expectedKeys:@[@"name", @"keen", @"#UUID"]
                 ];
            }];
}

- (void)testSetDefaultApiEndpoint {
    [TreasureData initializeApiEndpoint:@"https://another.apiendpoint.xyz"];
    [TreasureData initializeWithApiKey:@"hello_apikey"];
    NSString *url = [TreasureData sharedInstance].client.apiEndpoint;
    XCTAssertTrue([url isEqualToString:@"https://another.apiendpoint.xyz"]);
    self.isFinished = true;
}

- (void)testDisableUploading {
    [self baseTestingError:^() {
        self.client.enableRetryUploading = false;

        self.client.uploadRetryCount = 3;
        [self.td enableRetryUploading];

        self.session.expectedResponseBody = nil;

        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSString *ecode){
                XCTAssertEqualObjects(@"server_response", ecode);
                XCTAssertEqual(3, self.session.sendRequestCount);
            }];
}

- (void)testAutoAppendUuid {
    [self baseTesting:^() {
        MyTreasureData *anotherTd = [[MyTreasureData alloc] initWithApiKey:@"dummy_apikey"];
        [self.td enableAutoAppendUniqId];
        [self setupDefaultExpectedResponseBody:
                @{@"db0.tbl0":@[@{@"success":@"true"}],
                  @"db1.tbl1":@[@{@"success":@"true"}]}];

         [self.td addEvent:@{@"name":@"foobar"} database:@"db0" table:@"tbl0"];
        [anotherTd addEvent:@{@"name":@"helloworld"} database:@"db1" table:@"tbl1"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(2, ev.count);

                NSArray *arr = [ev objectForKey:@"db0.tbl0"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID", @"td_uuid"]
                 ];

                arr = [ev objectForKey:@"db1.tbl1"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"helloworld"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID"]
                 ];
}];
}

- (void)testAutoAppendModelInformation {
    [self baseTesting:^() {
        [self.td enableAutoAppendModelInformation];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID", @"td_device", @"td_model", @"td_os_ver", @"td_os_type"]
                 ];
            }];
}

- (void)testAutoAppendAppInformation {
    [self baseTesting:^() {
        [self.td enableAutoAppendAppInformation];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID", @"td_app_ver", @"td_app_ver_num"]
                 ];
            }];
}

- (void)testAutoAppendLocaleInformation {
    [self baseTesting:^() {
        [self.td enableAutoAppendLocaleInformation];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"name", @"keen", @"#UUID", @"td_locale_country", @"td_locale_lang"]
                 ];
            }];
}


- (void)testIsFirstRun {
    XCTAssertTrue([self.td isFirstRun]);
    [self.td clearFirstRun];
    XCTAssertFalse([self.td isFirstRun]);

    self.isFinished = true;
}

- (void)testSessionIdWithInstanceSession {
    [self baseTesting:^() {
        [self.td setDefaultDatabase:@"db_"];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        [self.td startSession:@"tbl"];
        [self.td addEvent:@{@"counter":@"one"} database:@"db_" table:@"tbl"];
        [self.td endSession:@"tbl" database:@"db_"];
        [self.td addEvent:@{@"counter":@"two"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                XCTAssertEqual(4, arr.count);
                NSString *uuidStartSession;
                NSString *uuidAddEvent;
                NSString *uuidEndSession;

                bool gotStartSession = false;
                bool gotAddEvent0 = false;
                bool gotEndSession = false;
                bool gotAddEvent1 = false;
                for (NSDictionary *x in arr) {
                    NSLog(@"%@", x);
                    if ([[x objectForKey:@"td_session_event"] isEqualToString:@"start"]) {
                        gotStartSession = true;
                        uuidStartSession = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"td_session_event"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"td_session_event"] isEqualToString:@"end"]) {
                        gotEndSession = true;
                        uuidEndSession = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"td_session_event"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"one"]) {
                        gotAddEvent0 = true;
                        uuidAddEvent = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"two"]) {
                        gotAddEvent1 = true;
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                }
                XCTAssertTrue(gotStartSession);
                XCTAssertTrue(gotEndSession);
                XCTAssertTrue(gotAddEvent0);
                XCTAssertTrue(gotAddEvent1);
                XCTAssertNotNil(uuidStartSession);
                XCTAssertEqualObjects(uuidStartSession, uuidEndSession);
                XCTAssertEqualObjects(uuidStartSession, uuidAddEvent);
            }];
}

- (void)testSessionIdWithInstanceSessionShouldBeChanged {
    [self baseTesting:^() {
        [self.td setDefaultDatabase:@"db_"];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        [self.td startSession:@"tbl"];
        [self.td endSession:@"tbl" database:@"db_"];
        [self.td startSession:@"tbl"];
        [self.td endSession:@"tbl" database:@"db_"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                XCTAssertEqual(4, arr.count);
                NSMutableSet *set = [[NSMutableSet alloc] init];
                for (NSDictionary *x in arr) {
                    NSLog(@"%@", x);
                    NSString *sessionIdAndEvent =
                    [NSString stringWithFormat:@"%@:%@",
                     [x objectForKey:@"td_session_id"],
                     [x objectForKey:@"td_session_event"]];
                    [set addObject:sessionIdAndEvent];
                }
                XCTAssertEqual(4, set.count);
            }];
}


- (void)testSessionIdWithGlobalSession {
    [self baseTesting:^() {
        [TreasureData setSessionTimeoutMilli:500];
        [self.td setDefaultDatabase:@"db_"];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        [TreasureData startSession];
        [self.td addEvent:@{@"counter":@"one"} database:@"db_" table:@"tbl"];
        [self.td addEvent:@{@"counter":@"two"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
        [self.td addEvent:@{@"counter":@"three"} database:@"db_" table:@"tbl"];
        [TreasureData startSession];
        [self.td addEvent:@{@"counter":@"four"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
        [NSThread sleepForTimeInterval:1.0];
        [TreasureData startSession];
        [self.td addEvent:@{@"counter":@"five"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                XCTAssertEqual(5, arr.count);
                NSString *uuidAddEventOne;
                NSString *uuidAddEventTwo;
                NSString *uuidAddEventFour;
                NSString *uuidAddEventFive;
                
                for (NSDictionary *x in arr) {
                    NSLog(@"%@", x);
                    if ([[x objectForKey:@"counter"] isEqualToString:@"one"]) {
                        uuidAddEventOne = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"two"]) {
                        uuidAddEventTwo = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"three"]) {
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"four"]) {
                        uuidAddEventFour = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"five"]) {
                        uuidAddEventFive = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"#UUID", @"keen", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else {
                        XCTFail(@"Shouldn't reach here");
                    }
                }
                XCTAssertNotNil(uuidAddEventOne);
                XCTAssertNotNil(uuidAddEventTwo);
                XCTAssertNotNil(uuidAddEventFour);
                XCTAssertNotNil(uuidAddEventFive);
                XCTAssertEqualObjects(uuidAddEventOne, uuidAddEventTwo);
                XCTAssertEqualObjects(uuidAddEventOne, uuidAddEventFour);
                XCTAssertNotEqualObjects(uuidAddEventOne, uuidAddEventFive);
            }];
}


- (void)testSingleEventWithoutCallbackWithWrongDatabaseName {
    [self.td addEvent:@{@"name":@"foobar"} database:@"DB_" table:@"tbl"];
    XCTAssertTrue(true);
    self.isFinished = true;
}

- (void)testSingleEventWithCallbackWithWrongDatabaseName {
    __block NSString* result;
    [self.td addEventWithCallback:@{@"name":@"foobar"}
                     database:@"DB_"
                        table:@"tbl"
                    onSuccess:^() {
                    }
                      onError:^(NSString* errorCode, NSString* message) {
                          result = errorCode;
                      }];
    XCTAssertTrue([result isEqualToString:@"invalid_param"]);
    self.isFinished = true;
}

- (void)testSingleEventWithoutCallbackWithWrongTableName {
    [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"TBL"];
    XCTAssertTrue(true);
    self.isFinished = true;
}

- (void)testSingleEventWithCallbackWithWrongTableName {
    __block NSString* result;
    [self.td addEventWithCallback:@{@"name":@"foobar"}
                         database:@"db_"
                            table:@"TBL"
                        onSuccess:^() {
                        }
                          onError:^(NSString* errorCode, NSString* message) {
                              result = errorCode;
                          }];
    XCTAssertTrue([result isEqualToString:@"invalid_param"]);
    self.isFinished = true;
}

@end
