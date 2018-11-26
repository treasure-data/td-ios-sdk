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

static NSString *testTable;

+ (void)setupTreasureData {
    [TreasureData enableLogging];
    // [TreasureData initializeApiEndpoint:@"https://specify-other-endpoint-if-needed.com"];
    [TreasureData initializeEncryptionKey:@"encryption_key"];
    [TreasureData initializeWithApiKey:@"api_key"];
    [[TreasureData sharedInstance] setDefaultDatabase:@"your_db"];
    [[TreasureData sharedInstance] setDefaultTable:@"audit_and_app_lifecycles"];
    [TreasureDataExample setTestTable:@"your_table"];
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
    [[TreasureData sharedInstance] enableAutoAppendRecordUUID];
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];
    [[TreasureData sharedInstance] enableAutoAppendAppInformation];
    [[TreasureData sharedInstance] enableAutoAppendLocaleInformation];
    [[TreasureData sharedInstance] enableServerSideUploadTimestamp:@"server_upload_time"];
}

+ (NSString *)testTable {
    return testTable;
}

+ (void)setTestTable:(NSString *)table {
    testTable = table;
}

@end
