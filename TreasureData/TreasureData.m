//
//  TreasureData.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 TreasureData Inc. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "TreasureData.h"
#import "TDHttpClient.h"
#import "KeenClient/KeenClient.h"

static BOOL isTraceLoggingEnabled = false;
static TreasureData *sharedInstance = nil;

@interface TDClient : KeenClient
@property(nonatomic, strong) NSString *apiKey;
@property(nonatomic, strong) NSString *apiEndpoint;
@end

@implementation TDClient
- (NSData *)sendEvents:(NSData *)data returningResponse:(NSURLResponse **)response error:(NSError **)error {
    NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.apiEndpoint, @"event"];
    KCLog(@"Sending events to: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.apiKey forHTTPHeaderField:@"X-TD-Write-Key"];
    [request setValue:@"k" forHTTPHeaderField:@"X-TD-Data-Type"];   // means KeenIO data type
    [request setHTTPBody:data];
    TDHttpClient *tdHttpClient = [[TDHttpClient alloc] init];
    if (isTraceLoggingEnabled) {
        [tdHttpClient setLogging:true];
    }
    return [tdHttpClient sendRequest:request returningResponse:response error:error];
}
@end

@interface TreasureData ()
@property(nonatomic, strong) TDClient *client;
@end

@implementation TreasureData
- (id)initWithApiKey:(NSString *)apiKey {
    [KeenClient disableGeoLocation];

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
        NSString *projectId = [NSString stringWithFormat:@"_td %@", [self md5:apiKey]];
        
        self.client = [[TDClient alloc] initWithProjectId:projectId andWriteKey:@"dummy_write_key" andReadKey:@"dummy_read_key"];
        if (self.client) {
            self.client.apiKey = apiKey;
            self.client.apiEndpoint = @"https://in.treasuredata.com/ios/v3";
        }
        else {
            KCLog(@"Failed to initialize client");
        }
    }
    return self;
}

- (NSString *) md5:(NSString *) input
{
    const char *cStr = [input UTF8String];
    unsigned char digest[16];
    CC_MD5(cStr, strlen(cStr), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

- (void)event:(NSDictionary *)record table:(NSString *)table {
    [self addEvent:record table:table];
}

- (void)event:(NSDictionary *)record database:(NSString *)database table:(NSString *)table {
    [self addEvent:record database:database table:table];
}

- (void)addEvent:(NSDictionary *)record table:(NSString *)table {
    [self addEvent:record database:self.defaultDatabase table:table];
}

- (void)addEvent:(NSDictionary *)record database:(NSString *)database table:(NSString *)table {
    if (self.client) {
        if (database && table) {
            NSString *tag = [NSString stringWithFormat:@"%@.%@", database, table];
            [self.client addEvent:record toEventCollection:tag error:nil];
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
    [self uploadEventsWithBlock:block];
}

- (void)uploadEventsWithBlock:(void (^)())block {
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

+ (void)initializeWithApiKey:(NSString *)apiKey {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithApiKey:apiKey];
    });
}

+ (instancetype)sharedInstance {
    NSAssert(sharedInstance, @"%@ sharedInstance called before withSecret", self);
    return sharedInstance;
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

@end
