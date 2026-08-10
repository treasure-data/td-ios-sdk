//
//  TreasureDataTests.m
//  TreasureDataTests
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TDConstants.h"
#import "TreasureData-Swift.h"

static NSString *END_POINT = @"http://localhost";

@interface TreasureData (Testing)
- (void)initializeFirstRun;
+ (void)resetSession;
@end

@interface MySessionDataTask : NSURLSessionDataTask
@end

@implementation MySessionDataTask
- (void)resume {}
@end

@interface MySession : NSURLSession
@property NSMutableArray *requestData;
@property NSData *expectedResponseBody;
@property NSURLResponse *expectedResponse;
@property int sendRequestCount;
@end

@implementation MySession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * __nullable data, NSURLResponse * __nullable response, NSError * __nullable error))completionHandler {
    @synchronized (self) {
        self.sendRequestCount++;
        if (self.requestData == nil) { self.requestData = [NSMutableArray new]; }
        [self.requestData addObject:request];
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:0.2];
        completionHandler(self.expectedResponseBody, self.expectedResponse, nil);
    });
    return (NSURLSessionDataTask*)[[MySessionDataTask alloc] init];
}
@end

// MyTreasureData used to be an ObjC subclass of TreasureData that overrode
// version getters, injected a mock session, and captured events. A Swift @objc
// class in a static library can't be subclassed from ObjC, so those hooks now
// live on TreasureData itself (mock* properties, capturingEvents/capturedEvents,
// injectable session). `MyTreasureData` is now just an alias, and makeTestTD
// configures a real TreasureData with the equivalent test hooks.
typedef TreasureData MyTreasureData;

static MyTreasureData *makeTestTD(NSString *apiKey) {
    MyTreasureData *td = [[TreasureData alloc] initWithApiKey:apiKey apiEndpoint:END_POINT];
    td.session = [[MySession alloc] init];
    td.capturingEvents = YES;
    // Match the former subclass's fixed app version/build.
    td.mockAppVersion = @"1.2.3";
    td.mockBuildNumber = @"42";
    return td;
}

#pragma mark -

@interface TreasureDataTests : XCTestCase
@property bool isFinished;
@property MyTreasureData* td;
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
    self.td = makeTestTD(@"dummy_apikey");
    [self.td initializeFirstRun];
    [self.td setDefaultDatabase:@"my_database"];
    self.session = (MySession*)self.td.session;
    [self.td clearAllBufferedEvents];
    [self.td clearCapturedEvents];
    [MyTreasureData disableEventCompression];
    [MyTreasureData resetSession];
    [self.td enableCustomEvent];
}

- (void)tearDown
{
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    } while (!self.isFinished);
    [[NSNotificationCenter defaultCenter] removeObserver:self.td];
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
    for (NSURLRequest *requestData in self.session.requestData) {
        NSString *url = [requestData.URL absoluteString];
        NSError *error = [NSError alloc];
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:requestData.HTTPBody options:0 error:&error];
        NSLog(@"response %@", response);
        NSDictionary *events = [response objectForKey:@"events"];
        NSDictionary *mappedEvents = @{[NSString stringWithFormat:@"%@.%@", [url stringByDeletingLastPathComponent].lastPathComponent,  url.lastPathComponent]: events};
        assertion(mappedEvents);
    }
}

- (void)baseTesting:(void(^)(void))setup onSuccess:(void(^)(void))onSuccess onError:(void(^)(NSString*, NSString*))onError {
    NSString *url = self.td.apiEndpoint;
    XCTAssertEqualObjects(@"http://localhost", url);

    [self setupDefaultExpectedResponse];

    setup();

    [self.td uploadEventsWithCallback:onSuccess onError:onError];
}

- (void)baseTesting:(void(^)(void))setup assertion:(void(^)(NSDictionary*))assert {
    [self baseTesting:setup onSuccess:^(){
        [self assertRequest:assert];
        self.isFinished = true;
    }
                              onError:^(NSString* ecode, NSString* detail){
                                  NSLog(@"ecode:%@, detail:%@", ecode, detail);
                                  XCTAssertTrue(false);
                                  self.isFinished = true;
                              }];
}

- (void)baseTestingError:(void(^)(void))setup assertion:(void(^)(NSString*))assertion {
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
                expectedKeys:@[@"time", @"name", @"uuid"]
             ];
        }];
}

- (void)testSingleEventWithDefaultDatabase {
    [self baseTesting:^() {
        self.td.defaultDatabase = @"db_";
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                     expectedKeys:@[@"time", @"name", @"uuid"]
                 ];
            }];
}

- (void)testMultiEvents {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{
            @"db0.tbl0":@[@{@"success":@"true"}, @{@"success":@"true"}],
            @"db1.tbl1":@[@{@"success":@"true"}]
        }];
        [self.td addEvent:@{@"name":@"one"} database:@"db0" table:@"tbl0"];
        [self.td addEvent:@{@"name":@"two"} database:@"db1" table:@"tbl1"];
        [self.td addEvent:@{@"name":@"three"} database:@"db0" table:@"tbl0"];
    }
            assertion:^(NSDictionary *ev){
        XCTAssertEqual(1, ev.count);
        NSArray *arr = [ev objectForKey:@"db0.tbl0"];
        if (arr != nil) {
            [self assertCollectedValueWithKey:arr
                                          key:@"name"
                                 expectedVals:@[@"one", @"three"]
                                 expectedKeys:@[@"time", @"name", @"uuid"]];
        }
        arr = [ev objectForKey:@"db1.tbl1"];
        if (arr != nil) {
            [self assertCollectedValueWithKey:arr
                                          key:@"name"
                                 expectedVals:@[@"two"]
                                 expectedKeys:@[@"time", @"name", @"uuid"]];
        }
    }];
}

#pragma mark - Engine seam: upload request shape

// The upload request is built in the Swift TDClient.sendEvents (the engine's
// KeenClient subclass). These lock the observable seam contract that a future
// engine replacement must keep: compression toggles the gzip Content-Encoding
// and body framing. setUp disables compression by default, so the default-path
// test covers the plain-JSON case.

- (void)testUploadWithoutCompressionSendsPlainJSON {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody:@{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                NSURLRequest *request = self.session.requestData.firstObject;
                // No gzip header, and the body is parseable JSON.
                XCTAssertNil([request valueForHTTPHeaderField:@"Content-Encoding"]);
                NSError *error = nil;
                id json = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:&error];
                XCTAssertNil(error);
                XCTAssertNotNil(json[@"events"]);
            }];
}

- (void)testUploadWithCompressionSendsGzip {
    [MyTreasureData enableEventCompression];
    // Use the low-level baseTesting: (no assertRequest, which would try to JSON-
    // parse the gzipped body); assert on the raw request in onSuccess instead.
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody:@{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
        onSuccess:^() {
            NSURLRequest *request = self.session.requestData.firstObject;
            XCTAssertEqualObjects(@"gzip", [request valueForHTTPHeaderField:@"Content-Encoding"]);
            // gzip streams start with the magic bytes 0x1f 0x8b.
            XCTAssertTrue(request.HTTPBody.length >= 2);
            const unsigned char *bytes = request.HTTPBody.bytes;
            XCTAssertEqual(0x1f, bytes[0]);
            XCTAssertEqual(0x8b, bytes[1]);
            [MyTreasureData disableEventCompression];
            self.isFinished = true;
        }
        onError:^(NSString* ecode, NSString* detail){
            XCTAssertTrue(false, @"unexpected error %@ / %@", ecode, detail);
            [MyTreasureData disableEventCompression];
            self.isFinished = true;
        }];
}

- (void)testSetDefaultApiEndpoint {
    [TreasureData initializeWithApiKey:@"hello_apikey" apiEndpoint:@"https://another.apiendpoint.xyz"];
    // Avoid it to trigger app lifecycle listener without some of the expectations (app's version) being mocked.
    [[NSNotificationCenter defaultCenter] removeObserver:[TreasureData sharedInstance]];
    NSString *url = [TreasureData sharedInstance].apiEndpoint;
    XCTAssertTrue([url isEqualToString:@"https://another.apiendpoint.xyz"]);
    self.isFinished = true;
}

// The p13n config properties are settable/gettable and, since this is an Obj-C
// test file, reaching them at all proves the @objc bridging.
- (void)testPersonalizationConfigProperties {
    XCTAssertNil(self.td.personalizationEndpoint);
    XCTAssertNil(self.td.personalizationToken);
    self.td.personalizationEndpoint = @"https://region.cdp-gw.in.treasuredata.com";
    self.td.personalizationToken = @"wp13n_token";
    XCTAssertEqualObjects(self.td.personalizationEndpoint, @"https://region.cdp-gw.in.treasuredata.com");
    XCTAssertEqualObjects(self.td.personalizationToken, @"wp13n_token");
    self.isFinished = true;
}

// trackImmediately POSTs the enriched record to the personalization endpoint
// (not the records endpoint) with both the write Authorization and the p13n
// read token. The body carries the same enrichment as addEvent.
- (void)testTrackImmediatelyPostsToPersonalizationEndpoint {
    [self setupDefaultExpectedResponse];
    self.td.personalizationEndpoint = @"http://localhost/p13n";
    self.td.personalizationToken = @"wp13n_token";
    self.td.defaultTable = @"events";
    [self.td enableAutoAppendUniqId]; // enrichment marker on the body

    XCTestExpectation *done = [self expectationWithDescription:@"trackImmediately result"];
    [self.td trackImmediately:@{@"event": @"pageview", @"screen": @"home"}
                        table:@"events"
                     onResult:^(BOOL shown) {
        // Nothing renders yet, so shown is false.
        XCTAssertFalse(shown);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssertEqual(1, self.session.sendRequestCount);
    NSURLRequest *req = self.session.requestData.firstObject;
    XCTAssertEqualObjects(req.URL.absoluteString, @"http://localhost/p13n/my_database/events");
    XCTAssertEqualObjects(req.HTTPMethod, @"POST");
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"Authorization"], @"TD1 dummy_apikey");
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"WP13n-Token"], @"wp13n_token");
    XCTAssertEqualObjects([req valueForHTTPHeaderField:@"Content-Type"], @"application/vnd.treasuredata.v1+json");

    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:req.HTTPBody options:0 error:nil];
    XCTAssertEqualObjects(body[@"event"], @"pageview");
    XCTAssertEqualObjects(body[@"screen"], @"home");
    XCTAssertNotNil(body[@"td_uuid"]); // proves the addEvent enrichment ran

    self.isFinished = true;
}

// With no personalization endpoint/token configured, trackImmediately makes no
// request and reports not-shown.
- (void)testTrackImmediatelyWithoutConfigMakesNoRequest {
    XCTestExpectation *done = [self expectationWithDescription:@"no-config result"];
    [self.td trackImmediately:@{@"event": @"pageview"}
                        table:@"events"
                     onResult:^(BOOL shown) {
        XCTAssertFalse(shown);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssertEqual(0, self.session.sendRequestCount);
    self.isFinished = true;
}

- (void)testDisableUploading {
    [self baseTestingError:^() {
        self.td.enableRetryUploadingFlag = false;

        self.td.uploadRetryCount = 3;
        [self.td enableRetryUploading];

        self.session.expectedResponseBody = nil;

        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSString *ecode){
                XCTAssertEqualObjects(@"server_response", ecode);
                XCTAssertEqual(3, self.session.sendRequestCount);
            }];
}

- (void)testEnableAutoAppendLocalTimestampWithDefaultColumnName {
    NSDate *now = [NSDate date];
    NSNumber *timestamp = [NSNumber numberWithInt:(int)now.timeIntervalSince1970];
    
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td enableAutoAppendLocalTimestamp];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
        XCTAssertEqual(1, self.session.sendRequestCount);
        XCTAssertEqual(1, ev.count);
        NSArray *arr = [ev objectForKey:@"db_.tbl"];
        [self assertCollectedValueWithKey:arr key:@"time" expectedVals:@[timestamp]
                             expectedKeys:@[@"name", @"uuid", @"time"]
        ];
    }];
}

- (void)testEnableAutoAppendLocalTimestamp {
    NSDate *now = [NSDate date];
    NSNumber *timestamp = [NSNumber numberWithInt:(int)now.timeIntervalSince1970];
    
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td enableAutoAppendLocalTimestamp:@"my_local_time"];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
        XCTAssertEqual(1, self.session.sendRequestCount);
        XCTAssertEqual(1, ev.count);
        NSArray *arr = [ev objectForKey:@"db_.tbl"];
        [self assertCollectedValueWithKey:arr key:@"my_local_time" expectedVals:@[timestamp]
                             expectedKeys:@[@"name", @"uuid", @"my_local_time"]
        ];
    }];
}

- (void)testDisableAutoAppendTimestamp {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td disableAutoAppendLocalTimestamp];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
        XCTAssertEqual(1, self.session.sendRequestCount);
        XCTAssertEqual(1, ev.count);
        NSArray *arr = [ev objectForKey:@"db_.tbl"];
        [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                             expectedKeys:@[@"name", @"uuid"]
        ];
    }];
}

- (void)testGetUUIDReturnsValue {
    [self.td enableAutoAppendUniqId];
    XCTAssertNotNil([self.td getUUID]);
    self.isFinished = true;
}

- (void)testAutoAppendUuid {
    [self baseTesting:^() {
        MyTreasureData *anotherTd = makeTestTD(@"dummy_apikey");
        [self.td enableAutoAppendUniqId];
        [self setupDefaultExpectedResponseBody:@{
            @"db0.tbl0":@[@{@"success":@"true"}],
            @"db1.tbl1":@[@{@"success":@"true"}]
        }];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db0" table:@"tbl0"];
        [anotherTd addEvent:@{@"name":@"helloworld"} database:@"db1" table:@"tbl1"];
    }
            assertion:^(NSDictionary *ev){
        XCTAssertEqual(2, self.session.sendRequestCount);
        XCTAssertEqual(1, ev.count);
        
        NSArray *arr = [ev objectForKey:@"db0.tbl0"];
        if (arr != nil) {
            [self assertCollectedValueWithKey:arr
                                          key:@"name"
                                 expectedVals:@[@"foobar"]
                                 expectedKeys:@[@"time", @"name", @"uuid", @"td_uuid"]];
        }
        
        arr = [ev objectForKey:@"db1.tbl1"];
        if (arr != nil) {
            [self assertCollectedValueWithKey:arr
                                          key:@"name"
                                 expectedVals:@[@"helloworld"]
                                 expectedKeys:@[@"time", @"name", @"uuid"]];
        }
    }];
}

- (void)testAutoAppendRecordUUIDWithDefaultColumnName {
    [self baseTesting:^() {
        [self.td enableAutoAppendRecordUUID];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"time", @"name", @"uuid", @"record_uuid"]
                 ];
            }];
}

- (void)testAutoAppendRecordUUID {
    [self baseTesting:^() {
        [self.td enableAutoAppendRecordUUID:@"my_record_uuid"];
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
            assertion:^(NSDictionary *ev){
                XCTAssertEqual(1, self.session.sendRequestCount);
                XCTAssertEqual(1, ev.count);
                NSArray *arr = [ev objectForKey:@"db_.tbl"];
                [self assertCollectedValueWithKey:arr key:@"name" expectedVals:@[@"foobar"]
                                     expectedKeys:@[@"time", @"name", @"uuid", @"my_record_uuid"]
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
                                     expectedKeys:@[@"time", @"name", @"uuid", @"td_device", @"td_model", @"td_os_ver", @"td_os_type"]
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
                                     expectedKeys:@[@"time", @"name", @"uuid", @"td_app_ver", @"td_app_ver_num"]
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
                                     expectedKeys:@[@"time", @"name", @"uuid", @"td_locale_country", @"td_locale_lang"]
                 ];
            }];
}

- (void)testAutoAppendAdvertisingIdEnabled {
    [self.td enableAutoAppendAdvertisingIdentifier];
    [self.td addEvent:[NSDictionary dictionary] table:@"somewhere"];
    [self assertEventCount:1];
    NSDictionary *sampleEvent= self.td.capturedEvents[0];
    XCTAssertNotNil(sampleEvent[@"td_maid"]);
    self.isFinished = true;
}

- (void)testAutoAppendAdvertisingIdDisabled {
    [self.td disableAutoAppendAdvertisingIdentifier];
    [self.td addEvent:[NSDictionary dictionary] table:@"somewhere"];
    [self assertEventCount:1];
    NSDictionary *sampleEvent= self.td.capturedEvents[0];
    XCTAssertNil(sampleEvent[@"td_maid"]);
    self.isFinished = true;
}

- (void)testIsFirstRun {
    XCTAssertTrue([self.td isFirstRun]);
    [self.td clearFirstRun];
    XCTAssertFalse([self.td isFirstRun]);

    self.isFinished = true;
}

- (void)testSessionIdWithInstanceSession {
    __block NSString *sessionId0;
    __block NSString *sessionId1;
    __block NSString *sessionId2;
    __block NSString *sessionId3;

    [self baseTesting:^() {
        self.td.defaultDatabase = @"db_";
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        sessionId0 = [self.td getSessionId];
        [self.td startSession:@"tbl"];
        sessionId1 = [self.td getSessionId];

        [self.td addEvent:@{@"counter":@"one"} database:@"db_" table:@"tbl"];
        sessionId2 = [self.td getSessionId];
        [self.td endSession:@"tbl" database:@"db_"];
        sessionId3 = [self.td getSessionId];
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
                                              [(@[@"time", @"uuid", @"td_session_id", @"td_session_event"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"td_session_event"] isEqualToString:@"end"]) {
                        gotEndSession = true;
                        uuidEndSession = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"td_session_id", @"td_session_event"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"one"]) {
                        gotAddEvent0 = true;
                        uuidAddEvent = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"two"]) {
                        gotAddEvent1 = true;
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
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
                XCTAssertNil(sessionId0);
                XCTAssertEqualObjects(sessionId1, uuidStartSession);
                XCTAssertEqualObjects(sessionId2, uuidStartSession);
                XCTAssertNil(sessionId3);
            }];
}

- (void)testSessionIdWithInstanceSessionShouldBeChanged {
    [self baseTesting:^() {
        self.td.defaultDatabase = @"db_";
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
    __block NSString *sessionId0;
    __block NSString *sessionId1;
    __block NSString *sessionId2;
    __block NSString *sessionId3;
    __block NSString *sessionId4;
    
    [self baseTesting:^() {
        [TreasureData setSessionTimeoutMilli:500];
        self.td.defaultDatabase = @"db_";
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        sessionId0 = [TreasureData getSessionId];
        [TreasureData startSession];
        sessionId1 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"one"} database:@"db_" table:@"tbl"];
        [self.td addEvent:@{@"counter":@"two"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
        [self.td addEvent:@{@"counter":@"three"} database:@"db_" table:@"tbl"];
        [TreasureData startSession];
        sessionId2 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"four"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
        [NSThread sleepForTimeInterval:1.0];
        [TreasureData startSession];
        sessionId3 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"five"} database:@"db_" table:@"tbl"];
        [TreasureData endSession];
        sessionId4 = [TreasureData getSessionId];
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
                                              [(@[@"time", @"uuid", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"two"]) {
                        uuidAddEventTwo = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"three"]) {
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"four"]) {
                        uuidAddEventFour = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
                                              );
                    }
                    else if ([[x objectForKey:@"counter"] isEqualToString:@"five"]) {
                        uuidAddEventFive = [x objectForKey:@"td_session_id"];
                        XCTAssertEqualObjects(
                                              [[x allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],
                                              [(@[@"time", @"uuid", @"td_session_id", @"counter"]) sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]
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
                XCTAssertNil(sessionId0);
                XCTAssertEqualObjects(sessionId1, uuidAddEventOne);
                XCTAssertEqualObjects(sessionId2, uuidAddEventFour);
                XCTAssertEqualObjects(sessionId3, uuidAddEventFive);
                XCTAssertNil(sessionId4);
            }];
}

- (void)testResetGlobalSessionId {
    __block NSString *sessionId1;
    __block NSString *sessionId2;
    __block NSString *sessionId3;
    
    [self baseTesting:^() {
        self.td.defaultDatabase = @"db_";
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}, @{@"success":@"true"}, @{@"success":@"true"}]}];
        [TreasureData startSession];
        sessionId1 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"one"} database:@"db_" table:@"tbl"];
        sessionId2 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"two"} database:@"db_" table:@"tbl"];
        [TreasureData resetSessionId];
        sessionId3 = [TreasureData getSessionId];
        [self.td addEvent:@{@"counter":@"three"} database:@"db_" table:@"tbl"];
    } assertion:^(NSDictionary *ev) {
        NSArray *arr = [ev objectForKey:@"db_.tbl"];
        NSString *eventSessionIdOne;
        NSString *eventSessionIdTwo;
        NSString *eventSessionIdThree;
        
        XCTAssertEqual(1, self.session.sendRequestCount);
        XCTAssertEqual(1, ev.count);
        XCTAssertEqual(3, arr.count);
        
        for (NSDictionary *x in arr) {
            if ([[x objectForKey:@"counter"] isEqualToString:@"one"]) {
                eventSessionIdOne = [x objectForKey:@"td_session_id"];
            } else if ([[x objectForKey:@"counter"] isEqualToString:@"two"]) {
                eventSessionIdTwo = [x objectForKey:@"td_session_id"];
            } else if ([[x objectForKey:@"counter"] isEqualToString:@"three"]) {
                eventSessionIdThree = [x objectForKey:@"td_session_id"];
            }
        }
        
        XCTAssertNotNil(eventSessionIdOne);
        XCTAssertNotNil(eventSessionIdTwo);
        XCTAssertNotNil(eventSessionIdThree);
        XCTAssertEqualObjects(sessionId1, eventSessionIdOne);
        XCTAssertEqualObjects(sessionId2, eventSessionIdTwo);
        XCTAssertEqualObjects(sessionId3, eventSessionIdThree);
        XCTAssertEqualObjects(eventSessionIdOne, eventSessionIdTwo);
        XCTAssertNotEqualObjects(eventSessionIdTwo, eventSessionIdThree);
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
                    onSuccess:^() {}
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

- (void)testOnSuccessIsCalledEvenWhenDataIsEmpty {
    [self.td uploadEventsWithCallback:^() {
        XCTAssertTrue(true);
        self.isFinished = true;
    }
                              onError:^(NSString* errorCode, NSString* message) {
                                  XCTAssertTrue(false);
                                  self.isFinished = true;
                              }
     ];
}

#pragma mark - Auto Tracking

- (void)testAutoTrackAppOpened {
    [self.td enableAppLifecycleEvent];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationDidFinishLaunchingNotification"
                                                            object:nil];
    [self assertHasCapturedEventType:TD_EVENT_APP_OPENED];
    self.isFinished = true;
}

- (void)testAutoTrackAppInstalled {
    @try {
        self.td.mockTrackedAppVersion = nil;
        self.td.mockTrackedBuildNumber = nil;
        [self.td enableAppLifecycleEvent];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationDidFinishLaunchingNotification"
                                                            object:nil];
        [self assertEventCount:2];
        [self assertHasCapturedEventType:TD_EVENT_APP_INSTALLED];
        [self assertHasCapturedEventType:TD_EVENT_APP_OPENED];
    } @finally {
        self.isFinished = true;
    }
}

- (void)testAutoTrackEventUpdated {
    // Previous installed version
    self.td.mockTrackedAppVersion = @"0.0.1";
    self.td.mockTrackedBuildNumber = @"1";
    // Current version is overriden by the mock* hooks
    @try {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationDidFinishLaunchingNotification"
                                                            object:nil];
        [self assertEventCount:2];
        [self assertHasCapturedEventType:TD_EVENT_APP_UPDATED];
        [self assertHasCapturedEventType:TD_EVENT_APP_OPENED];
    } @finally {
        self.isFinished = true;
    }
}

#pragma mark - GDPR Compliancy

- (void)testToggleAllowCustomEvent {
    @try {
        [self.td disableCustomEvent];
        [self.td uploadEvents];
        // All events are supposed to be flushed
        [self assertEventCount:0];
        id added = [self.td addEvent:[NSDictionary dictionary] table:@"somewhere"];
        // Expect no events were recorded
        XCTAssertNil(added);
        [self assertEventCount:0];
    } @finally {
        self.isFinished = true;
    }
}

- (void)testToggleAllowAppLifecycleEvent {
    @try {
        [self.td disableAppLifecycleEvent];
        [self.td uploadEvents];
        // All events are supposed to be flushed
        [self assertEventCount:0];
        // Normally this would trigger the TD_EVENT_APP_OPENED event
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationDidFinishLaunchingNotification"
                                                            object:nil];
        // Expect no events were recorded
        [self assertEventCount:0];
    } @finally {
        self.isFinished = true;
    }
}

- (void)testResetUniqId {
    @try {
        [self.td setDefaultDatabase:@"somedb"];
        [self.td enableAutoAppendUniqId];
        [self.td enableCustomEvent];
        [self.td addEvent:[NSDictionary dictionary] table:@"somewhere"];
        NSDictionary *sampleEvent= self.td.capturedEvents[0];
        NSString* uuid = sampleEvent[@"td_uuid"];

        [self.td uploadEvents];
        [self.td resetUniqId];
        [self assertHasCapturedEventType:TD_EVENT_AUDIT_RESET_UUID];
        [self.td uploadEvents];
        [self.td addEvent:[NSDictionary dictionary] table:@"somewhere"];
        NSDictionary *sampleEventAfterReset= self.td.capturedEvents[0];
        NSString* uuidAfterReset = sampleEventAfterReset[@"td_uuid"];

        XCTAssertNotEqual(uuid, uuidAfterReset);
    } @finally {
        self.isFinished = true;
    }
}

// By default, without any explicit configuration, the SDK should
// collecting minimal metadata as possible
- (void)testMinimalCollectingByDefault {
    NSDictionary *decoratedEvent = [self.td addEvent:@{@"testKey": @"testVal"} table:@"my_table"];
    XCTAssertEqual([decoratedEvent count], 2);
    self.isFinished = YES;
}

// Some metadata such as `__td_event_class` are automatically added,
// which is the SDK implementation details and irrelavant on the service side.
// We should making sure we don't accidentally included those on the final events
- (void)testAddedEventShouldNotHaveTheNonEventDataAdded {
    [self.td enableCustomEvent];
    // Although actually, custom events won't be marked with __td_event_class,
    // if the key is absence, then it is treated as custom events
    NSDictionary *myEvent = [TDUtils markAsCustomEvent:@{@"mykey": @"myvalue"}];
    NSDictionary *event = [self.td addEvent:myEvent table:@"somewhere"];
    XCTAssertNil([event objectForKey:TDUtils.eventClassKey]);
    self.isFinished = YES;
}

#pragma mark - Tracking td_ip

- (void)testTrackingIPEnabled {
    @try {
        XCTAssertFalse(self.td.enableTrackingIP);
        [self.td enableAutoTrackingIP];
        XCTAssertTrue(self.td.enableTrackingIP);
    } @finally {
        self.isFinished = YES;
    }
}

- (void)testTrackingIPDisabled {
    @try {
        [self.td enableAutoTrackingIP];
        XCTAssertTrue(self.td.enableTrackingIP);
        [self.td disableAutoTrackingIP];
        XCTAssertFalse(self.td.enableTrackingIP);
    } @finally {
        self.isFinished = YES;
    }
}

#pragma mark - Default Values

- (void) testAddDefaultValuesSuccesfully {
    [self.td setDefaultValue:@"String" forKey:@"string" database:nil table:nil];
    [self.td setDefaultValue:@1 forKey:@"number" database:nil table:nil];
    [self.td setDefaultValue:@"Only 1" forKey:@"only_1" database:@"test_db" table:@"test_table"];
    [self.td setDefaultValue:@"Only 2" forKey:@"only_2" database:@"test_db_2" table:@"test_table_2"];
    [self.td setDefaultValue:@"Any Table" forKey:@"any_table" database:@"test_db" table:nil];
    [self.td setDefaultValue:@"Any Table 2" forKey:@"any_table_2" database:@"test_db_2" table:nil];
    [self.td setDefaultValue:@"Any Database" forKey:@"any_db" database:nil table:@"test_table"];
    [self.td setDefaultValue:@"Any Database 2" forKey:@"any_db_2" database:nil table:@"test_table_2"];

    [self.td addEvent:@{@"key1": @"value1"} database:@"test_db" table:@"test_table"];
    [self.td addEvent:@{@"key2": @"value2"} database:@"test_db_2" table:@"test_table_2"];
    
    [self assertEventCount:2];
    NSDictionary *sampleEvent= self.td.capturedEvents[0];
    NSDictionary *sampleEvent2= self.td.capturedEvents[1];
    
    XCTAssertEqual(sampleEvent[@"key1"], @"value1");
    XCTAssertEqual(sampleEvent[@"string"], @"String");
    XCTAssertEqual(sampleEvent[@"number"], @1);
    XCTAssertEqual(sampleEvent[@"only_1"], @"Only 1");
    XCTAssertNil(sampleEvent[@"only_2"]);
    XCTAssertEqual(sampleEvent[@"any_table"], @"Any Table");
    XCTAssertNil(sampleEvent[@"any_table_2"]);
    XCTAssertEqual(sampleEvent[@"any_db"], @"Any Database");
    XCTAssertNil(sampleEvent[@"any_db_2"]);
    
    XCTAssertEqual(sampleEvent2[@"key2"], @"value2");
    XCTAssertEqual(sampleEvent2[@"string"], @"String");
    XCTAssertEqual(sampleEvent2[@"number"], @1);
    XCTAssertEqual(sampleEvent2[@"only_2"], @"Only 2");
    XCTAssertNil(sampleEvent2[@"only_1"]);
    XCTAssertNil(sampleEvent2[@"any_table"]);
    XCTAssertEqual(sampleEvent2[@"any_table_2"], @"Any Table 2");
    XCTAssertNil(sampleEvent2[@"any_db"]);
    XCTAssertEqual(sampleEvent2[@"any_db_2"], @"Any Database 2");
    
    self.isFinished = true;
}

- (void)testAddDefaultValuesOverrideSuccesfully {
    [self.td setDefaultValue:@"Any Table & DB" forKey:@"key" database:nil table:nil];
    [self.td addEvent:@{@"key1": @"value1"} database:@"test_db" table:@"test_table"];
    
    [self.td setDefaultValue:@"Any Table" forKey:@"key" database:@"test_db" table:nil];
    [self.td addEvent:@{@"key2": @"value2"} database:@"test_db" table:@"test_table"];
    
    [self.td setDefaultValue:@"Any DB" forKey:@"key" database:nil table:@"test_table"];
    [self.td addEvent:@{@"key3": @"value3"} database:@"test_db" table:@"test_table"];
    
    [self.td setDefaultValue:@"Specific Table & DB" forKey:@"key" database:@"test_db" table:@"test_table"];
    [self.td addEvent:@{@"key4": @"value4"} database:@"test_db" table:@"test_table"];
    
    [self.td addEvent:@{@"key": @"Event Value"} database:@"test_db" table:@"test_table"];
    
    [self assertEventCount:5];
    XCTAssertEqual(self.td.capturedEvents[0][@"key"], @"Any Table & DB");
    XCTAssertEqual(self.td.capturedEvents[1][@"key"], @"Any Table");
    XCTAssertEqual(self.td.capturedEvents[2][@"key"], @"Any DB");
    XCTAssertEqual(self.td.capturedEvents[3][@"key"], @"Specific Table & DB");
    XCTAssertEqual(self.td.capturedEvents[4][@"key"], @"Event Value");
    
    self.isFinished = true;
}

- (void)testGetDefaultValueForKey {
    [self.td setDefaultValue:@"Value" forKey:@"key" database:nil table:nil];
    [self.td setDefaultValue:@"Value" forKey:@"key_table" database:nil table:@"test_table"];
    [self.td setDefaultValue:@"Value" forKey:@"key_database" database:@"test_db" table:nil];
    [self.td setDefaultValue:@"Value" forKey:@"key_table_database" database:@"test_db" table:@"test_table"];
    
    NSString *nilKeyValue = [self.td defaultValueForKey:@"nilKey" database:nil table:nil];
    NSString *keyValue = [self.td defaultValueForKey:@"key" database:nil table:nil];
    NSString *keyTableValue = [self.td defaultValueForKey:@"key_table" database:nil table:@"test_table"];
    NSString *keyDBValue = [self.td defaultValueForKey:@"key_database" database:@"test_db" table:nil];
    NSString *keyTableDBValue = [self.td defaultValueForKey:@"key_table_database" database:@"test_db" table:@"test_table"];
    
    XCTAssertNil(nilKeyValue);
    XCTAssertEqual(keyValue, @"Value");
    XCTAssertEqual(keyTableValue, @"Value");
    XCTAssertEqual(keyDBValue, @"Value");
    XCTAssertEqual(keyTableDBValue, @"Value");
    
    self.isFinished = true;
}

- (void)testRemoveDefaultValuesSuccessfully {
    [self.td setDefaultValue:@"Value" forKey:@"key" database:nil table:nil];
    [self.td setDefaultValue:@"Value" forKey:@"key_table" database:nil table:@"test_table"];
    [self.td setDefaultValue:@"Value" forKey:@"key_database" database:@"test_db" table:nil];
    [self.td setDefaultValue:@"Value" forKey:@"key_table_database" database:@"test_db" table:@"test_table"];
    [self.td addEvent:@{@"key1": @"value1"} database:@"test_db" table:@"test_table"];
    [self.td removeDefaultValueForKey:@"key" database:nil table:nil];
    [self.td removeDefaultValueForKey:@"key_table" database:nil table:@"test_table"];
    [self.td removeDefaultValueForKey:@"key_database" database:@"test_db" table:nil];
    [self.td removeDefaultValueForKey:@"key_table_database" database:@"test_db" table:@"test_table"];
    [self.td addEvent:@{@"key2": @"value2"} database:@"test_db" table:@"test_table"];
    
    [self assertEventCount:2];
    XCTAssertEqual(self.td.capturedEvents[0][@"key"], @"Value");
    XCTAssertEqual(self.td.capturedEvents[0][@"key_table"], @"Value");
    XCTAssertEqual(self.td.capturedEvents[0][@"key_database"], @"Value");
    XCTAssertEqual(self.td.capturedEvents[0][@"key_table_database"], @"Value");
    XCTAssertNil(self.td.capturedEvents[1][@"key"]);
    XCTAssertNil(self.td.capturedEvents[1][@"key_table"]);
    XCTAssertNil(self.td.capturedEvents[1][@"key_database"]);
    XCTAssertNil(self.td.capturedEvents[1][@"key_table_database"]);
    
    self.isFinished = true;
}

- (void)testRemoveDefaultValuesNoop {
    [self.td setDefaultValue:@"Value" forKey:@"key" database:nil table:nil];
    [self.td removeDefaultValueForKey:@"key" database:nil table:@"test_table"];
    [self.td removeDefaultValueForKey:@"key" database:@"test_db" table: nil];
    [self.td removeDefaultValueForKey:@"key" database:@"test_db" table:@"test_table"];
    [self.td removeDefaultValueForKey:@"key2" database:nil table:nil];
    [self.td addEvent:@{@"key1": @"value1"} database:@"test_db" table:@"test_table"];

    [self assertEventCount:1];
    XCTAssertEqual(self.td.capturedEvents[0][@"key"], @"Value");
    XCTAssertNil(self.td.capturedEvents[0][@"key2"]);
    self.isFinished = true;
}

#pragma mark - Assertions

- (void)assertHasCapturedEventType:(NSString *)eventType {
    BOOL test = [self hasCapturedEventType:eventType];
    XCTAssertTrue(test, @"Expected event type has never been captured!");
}

- (BOOL)hasCapturedEventType:(NSString *)eventType {
    NSArray<NSDictionary<NSString *,id> *> *events = self.td.capturedEvents;
    for (int i = 0; i < events.count; i++) {
        if ([[events objectAtIndex:i][TD_COLUMN_EVENT] isEqualToString:eventType]) {
            return true;
        }
    }
    return false;
}

- (void)assertHasCapturedEventClass:(NSString *)eventType {
    NSArray<NSDictionary<NSString *,id> *> *events = self.td.capturedEvents;
    for (int i = 0; i < events.count; i++) {
        if ([TDUtils isAuditEvent:[events objectAtIndex:i]]) {
            return;
        }
    }
    @throw [NSString stringWithFormat:@"Event class: \"%@\" has never been captured!", eventType];
}

- (void)assertEventCount:(NSUInteger)eventNumber
{
    XCTAssertEqual(self.td.capturedEvents.count, eventNumber);
}

@end
