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

@interface TreasureDataTests : XCTestCase

@end


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
@end

@implementation TreasureDataTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSingleEvent {
    MyTreasureData *td = [[MyTreasureData alloc] initWithApiKey:@"dummy_apikey"];
    [td addEvent:@{@"name":@"foobar"} database:@"db_" table:@"tbl"];
    [td uploadEvents];
    NSLog(@"%@", td.client.apiKey);
}


@end
