//
//  TDClinet.m
//  TreasureData
//
//  Created by Mitsunori Komatsu on 12/15/14.
//  Copyright (c) 2014 Mitsunori Komatsu. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import "Deflate.h"
#import "TDClient.h"

static NSString *version = @"0.1.14";

@implementation TDClient

- (id)initWithApiKey:(NSString *)apiKey apiEndpoint:(NSString*)apiEndpoint {
    NSString *projectId = [NSString stringWithFormat:@"_td %@", [self md5:apiKey]];
    self = [self initWithProjectId:projectId andWriteKey:@"dummy_write_key" andReadKey:@"dummy_read_key"];
    self.apiKey = apiKey;
    self.apiEndpoint = apiEndpoint;
    self.globalPropertiesBlock = ^NSDictionary *(NSString *eventCollection) {
        if (!NSClassFromString(@"NSUUID")) {
            return @{};
        }
        return @{@"#UUID": [[NSUUID UUID] UUIDString]};
    };
    /*
     > 5.times.inject(0){|a, i| puts a; x = 4 * (2 ** i); a += x; a}
     0
     4
     12
     28
     60
    */
    self.uploadRetryIntervalCoeficient = 4;
    self.uploadRetryIntervalBase = 2;
    self.uploadRetryCount = 5;
    self.enableRetryUploading = true;
    return self;
}

- (NSString *) md5:(NSString *) input
{
    const char *cStr = [input UTF8String];
    unsigned char digest[16];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

- (NSData *)sendEvents:(NSData *)data returningResponse:(NSURLResponse **)response error:(NSError **)error {
    NSString *urlString = [NSString stringWithFormat:@"%@/%@", self.apiEndpoint, @"ios/v3/event"];
    KCLog(@"Sending events to: %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:self.apiKey forHTTPHeaderField:@"X-TD-Write-Key"];
    [request setValue:@"k" forHTTPHeaderField:@"X-TD-Data-Type"];   // means KeenIO data type
    [request setValue:[NSString stringWithFormat:@"TD-iOS-SDK/%@ (%@ %@)", version, [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]] forHTTPHeaderField:@"User-Agent"];
    
    if (self.enableEventCompression) {
        NSData *compressedData = [Deflate deflate:data];
        if (!compressedData) {
            KCLog(@"Compression failed");
        }
        else {
            KCLog(@"Compressed: before=%ld, after=%ld", (unsigned long)[data length], (unsigned long)[compressedData length]);
            data = compressedData;
            /*
             Byte* bytes = [data bytes];
             for (int i=0; i < [data length]; i++) {
             NSLog(@"byte[%d]: 0x%02x", i, bytes[i]);
             }
             */
            [request setValue:@"deflate" forHTTPHeaderField:@"Content-Encoding"];
        }
    }
    
    [request setHTTPBody:data];
    
    for (int i = 0; i < self.uploadRetryCount; i++) {
        NSData *responseData = [self sendHTTPRequest:request returningResponse:response error:error];
        if (responseData) {
            return responseData;
        }
        else {
            KCLog(@"sendSynchronousRequest error occurred(%@/%@)", [NSNumber numberWithInt:i], [NSNumber numberWithInt:self.uploadRetryCount]);
            if (!self.enableRetryUploading || i >= self.uploadRetryCount - 1) {
                return nil;
            }
            double wait = self.uploadRetryIntervalCoeficient * pow(self.uploadRetryIntervalBase, i);
            [NSThread sleepForTimeInterval:wait];
        }
    }
    return nil;
}

- (NSData*) sendHTTPRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:response error:error];
    return responseData;
}

@end
