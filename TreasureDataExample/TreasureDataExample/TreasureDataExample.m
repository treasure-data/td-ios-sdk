//
//  TreasureDataExample.m
//  TreasureDataExample
//
//  Created by Huy Le on 4/17/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TreasureData.h"
#import "TreasureDataExample.h"

@implementation TreasureDataExample

+(void)setupTreasureDataWithEndpoint:(NSString *)endpoint
                              apiKey:(NSString *)apiKey
                            database:(NSString *)database {
    [TreasureData enableLogging];
    if (endpoint != nil) {
        [TreasureData initializeApiEndpoint:endpoint];
    }
    [TreasureData initializeEncryptionKey:@"hello world"];
    [TreasureData initializeWithApiKey:apiKey];
    [[TreasureData sharedInstance] setDefaultDatabase:database];
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
    [[TreasureData sharedInstance] enableAutoAppendRecordUUID];
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];
    [[TreasureData sharedInstance] enableAutoAppendAppInformation];
    [[TreasureData sharedInstance] enableAutoAppendLocaleInformation];
    [[TreasureData sharedInstance] enableServerSideUploadTimestamp:@"server_upload_time"];
}

@end
