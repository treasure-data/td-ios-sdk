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
@property NSURLRequest *requestData;
@property NSData *expectedResponseBody;
@property NSURLResponse *expectedResponse;
@end

@implementation MyTDClient
- (NSData*) sendHTTPRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    self.requestData = request;
    *response = self.expectedResponse;
    return self.expectedResponseBody;
}
@end

@interface MyTreasureData : TreasureData
@end

@implementation MyTreasureData
- (id)initWithApiKey:(NSString *)apiKey {
    self = [super initWithApiKey:apiKey];
    MyTDClient *myClient = [[MyTDClient alloc] initWithApiKey:apiKey apiEndpoint:END_POINT];
    self.client = myClient;
    return self;
}
@end

@interface TreasureDataTests : XCTestCase
@property bool isFinished;
@property MyTreasureData* td;
@property MyTDClient *client;
@end

@implementation TreasureDataTests

- (void)setUp
{
    self.td = [[MyTreasureData alloc] initWithApiKey:@"dummy_apikey"];
    self.client = (MyTDClient*)self.td.client;
    [[MyTDClient getEventStore] deleteAllEvents];
    [MyTreasureData disableEventCompression];
    [super setUp];
}

- (void)tearDown
{
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    } while (!self.isFinished);
    [super tearDown];
}

- (void)setupDefaultExpectedResponse {
    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    self.client.expectedResponse = expectedResponse;
}

- (void)setupDefaultExpectedResponseBody:(NSDictionary*)dict {
    NSError *error = [NSError alloc];
    NSData *expectedResponseBody = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    self.client.expectedResponseBody = expectedResponseBody;
}

- (void)assertRequest:(void(^)(NSDictionary*))assertion {
    NSString *url = [self.client.requestData.URL absoluteString];
    XCTAssertTrue([@"http://localhost/ios/v3/event" isEqualToString:url]);
    NSError *error = [NSError alloc];
    NSDictionary *ev = [NSJSONSerialization JSONObjectWithData:self.client.requestData.HTTPBody options:0 error:&error];
    assertion(ev);
}

- (void)baseTesting:(void(^)())setup assertion:(void(^)(NSDictionary*))assert {
    [self setupDefaultExpectedResponse];

    setup();
    
    [self.td uploadEventsWithCallback:^(){
        [self assertRequest:assert];
        self.isFinished = true;
    }
      onError:^(NSString* ecode, NSString* detail){
          XCTAssertTrue(false);
          self.isFinished = true;
      }];
}

- (void)testSingleEvent {
    [self baseTesting:^() {
        [self setupDefaultExpectedResponseBody: @{@"db_.tbl":@[@{@"success":@"true"}]}];
        [self.td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    }
        assertion:^(NSDictionary *ev){
            XCTAssertEqual(1, ev.count);
            NSArray *arr = [ev objectForKey:@"db_.tbl"];
            XCTAssertEqual(1, arr.count);
            NSDictionary *dict = [arr objectAtIndex:0];
            XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"foobar"]);
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
                XCTAssertEqual(1, arr.count);
                NSDictionary *dict = [arr objectAtIndex:0];
                XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"foobar"]);
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
                XCTAssertEqual(2, arr.count);
                NSDictionary *dict = [arr objectAtIndex:0];
                XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"one"]);
                dict = [arr objectAtIndex:1];
                XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"three"]);
                
                arr = [ev objectForKey:@"db1.tbl1"];
                XCTAssertEqual(1, arr.count);
                dict = [arr objectAtIndex:0];
                XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"two"]);
            }];
}

@end
