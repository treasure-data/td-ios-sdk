//
//  SessionTests.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 6/23/16.
//  Copyright © 2014 Treasure Data. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Session.h"

@interface SessionTests : XCTestCase

@end

@implementation SessionTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testGetIdReturnsNullWithoutStart {
    Session* session = [Session new];
    XCTAssertNil([session getId]);
}

- (void) testStartShouldActivateId {
    Session* session = [Session new];
    [session start];
    NSString *firstSessionId = [session getId];
    XCTAssertNotNil(firstSessionId);

    NSString *sessionId = [session getId];
    XCTAssertNotNil(sessionId);
    XCTAssertEqual(firstSessionId, sessionId);
}

- (void) testFinishShouldInactivateId {
    Session* session = [Session new];
    [session start];
    [session finish];
    XCTAssertNil([session getId]);
}

- (void) testReStartWithinIntervalShouldReuseId {
    Session* session = [Session new];

    [session start];
    NSString *firstSessionId = [session getId];
    XCTAssertNotNil(firstSessionId);
    [session finish];

    [session start];
    NSString *secondSessionId = [session getId];
    XCTAssertNotNil(secondSessionId);
    [session finish];
    XCTAssertEqual(firstSessionId, secondSessionId);
}

- (void) testReStartAfterExpirationShouldNotReuseId {
    Session* session = [Session new];
    session.sessionPendingMillis = 500;
    
    [session start];
    NSString *firstSessionId = [session getId];
    XCTAssertNotNil(firstSessionId);
    [session finish];
    
    [NSThread sleepForTimeInterval:1.0];
    
    [session start];
    NSString *secondSessionId = [session getId];
    XCTAssertNotNil(secondSessionId);
    [session finish];
    XCTAssertNotEqual(firstSessionId, secondSessionId);
}

- (void) testReStartWithoutFinishShouldNotUpdateId {
    Session* session = [Session new];

    [session start];
    NSString *firstSessionId = [session getId];
    XCTAssertNotNil(firstSessionId);

    [session start];
    NSString *secondSessionId = [session getId];
    XCTAssertNotNil(firstSessionId);
    
    XCTAssertEqual(firstSessionId, secondSessionId);
}

@end
