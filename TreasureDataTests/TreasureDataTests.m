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
@interface TreasureDataTests : XCTestCase
@property bool isFinished;
@end


@interface MyTDClient : TDClient
@property NSURLRequest *requestData;
@property NSData *expectedResponseBody;
@property NSURLResponse *expectedResponse;
@end

@interface MyTDClient ()
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

@implementation TreasureDataTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    } while (!self.isFinished);
    [super tearDown];
}

- (void)testSingleEvent {
    MyTreasureData *td = [[MyTreasureData alloc] initWithApiKey:@"dummy_apikey"];
    [[MyTDClient getEventStore] deleteAllEvents];
    MyTDClient* client = (MyTDClient*)td.client;
    [MyTreasureData disableEventCompression];
    
    NSHTTPURLResponse *expectedResponse = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
    client.expectedResponse = expectedResponse;
    
    NSError *error = [NSError alloc];
    NSData *expectedResponseBody = [NSJSONSerialization dataWithJSONObject:@{@"db_.tbl":@[@{@"success":@"true"}]} options:0 error:&error];
    client.expectedResponseBody = expectedResponseBody;
    
    [td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl" ];
    [td uploadEventsWithCallback:^(){
        NSString *url = [client.requestData.URL absoluteString];
        XCTAssertTrue([@"http://localhost/ios/v3/event" isEqualToString:url]);
        NSError *error = [NSError alloc];
        NSDictionary *ev = [NSJSONSerialization JSONObjectWithData:client.requestData.HTTPBody options:0 error:&error];
        XCTAssertEqual(1, ev.count);
        NSArray *arr = [ev objectForKey:@"db_.tbl"];
        XCTAssertEqual(1, arr.count);
        NSDictionary *dict = [arr objectAtIndex:0];
        XCTAssertTrue([[dict objectForKey:@"name"] isEqualToString:@"foobar"]);
        self.isFinished = true;
    }
                          onError:^(NSString* ecode, NSString* detail){
                              XCTAssertTrue(false);
                              self.isFinished = true;
                          }
     ];
}


@end
