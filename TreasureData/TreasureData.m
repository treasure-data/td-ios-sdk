//
//  TreasureData.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "TreasureData.h"
#import "KeenClient/KeenClient.h"

@interface MyClient : KeenClient
@property(nonatomic, strong) NSString *apiKey;
@property(nonatomic, strong) NSString *apiEndpoint;
@end

@implementation MyClient
- (NSData *)sendEvents:(NSData *)data returningResponse:(NSURLResponse **)response error:(NSError **)error {
    NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.apiEndpoint, @"event"];
    KCLog(@"Sending request to: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.apiKey forHTTPHeaderField:@"X-TD-Write-Key"];
    [request setValue:@"k" forHTTPHeaderField:@"X-TD-Data-Type"];   // means KeenIO data type
    [request setHTTPBody:data];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:response error:error];
    KCLog(@"response=%@", *response);
    KCLog(@"responseData=%@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
    KCLog(@"error=%@", *error);

    return responseData;
}
@end

@interface TreasureData ()
@property MyClient *client;
@end

@implementation TreasureData

- (id)initWithSecret:(NSString *)secret {
    self.client = [[MyClient alloc] initWithProjectId:@"_treasure data_" andWriteKey:@"dummy_write_key" andReadKey:@"dummy_read_key"];
    if (self.client) {
        self.client.apiKey = secret;
        self.client.apiEndpoint = @"http://in.treasuredata.com/ios/v3";
    }
    else {
        KCLog(@"Failed to initialize client");
    }
    return self;
}

- (void)event:(NSString *)database table:(NSString *)table {
    [self event:database table:table properties:nil options:nil];
}

- (void)event:(NSString *)database table:(NSString *)table properties:(NSDictionary *)properties {
    [self event:database table:table properties:properties options:nil];
}

- (void)event:(NSString *)database table:(NSString *)table properties:(NSDictionary *)properties options:(NSDictionary *)options {
    if (self.client) {
        if (database && table) {
            NSString *tag = [NSString stringWithFormat:@"%@.%@", database, table];
            [self.client addEvent:properties toEventCollection:tag error:nil];
        }
        else {
            KCLog(@"database or table is nil: database=%@, table=%@", database, table);
        }
    }
    else {
        KCLog(@"Client is nil");
    }
}

- (void)uploadWithBlock:(void (^)())block {
    if (self.client) {
        [self.client uploadWithFinishedBlock:block];
    }
    else {
        KCLog(@"Client is nil");
    }
}

- (void)setApiEndpoint:(NSString*)endpoint {
    self.client.apiEndpoint = endpoint;
}

static TreasureData *SharedInstance = nil;

+ (void)initializeWithSecret:(NSString *)secret {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SharedInstance = [[self alloc] initWithSecret:secret];
    });
}

+ (instancetype)sharedInstance {
    NSAssert(SharedInstance, @"%@ sharedInstance called before withSecret", self);
    return SharedInstance;
}

+ (void)disableLogging {
    [KeenClient disableLogging];
}

+ (void)enableLogging {
    [KeenClient enableLogging];
}

@end
