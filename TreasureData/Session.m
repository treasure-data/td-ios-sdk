//
//  Session.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 6/22/16.
//  Copyright © 2014 Treasure Data. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Session.h"

static int DEFAULT_SESSION_PENDING_MILLIS = 10 * 1000;

@interface Session ()
@property NSString *id;
@property NSDate *finishedAt;
@end

@implementation Session
+ (Session*) new {
    Session* session = [Session alloc];
    session.sessionPendingMillis = DEFAULT_SESSION_PENDING_MILLIS;
    return session;
}

- (void) start {
    if (!self.id || (self.finishedAt && [self.finishedAt timeIntervalSinceNow] * (-1000) > self.sessionPendingMillis)) {
        self.id = [[NSUUID UUID] UUIDString];
    }
    self.finishedAt = nil;
}

- (void) finish {
    if (self.id && !self.finishedAt) {
        self.finishedAt = [NSDate date];
    }
}

- (NSString*) getId {
    if (!self.id || self.finishedAt) {
        return nil;
    }
    return self.id;
}
@end
