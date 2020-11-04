//
//  ViewController.m
//  TreasureDataTVOSExample
//
//  Created by Tung Vu on 10/16/20.
//  Copyright © 2020 Treasure Data. All rights reserved.
//

#import "TVOSViewController.h"
#import "TreasureData.h"

@interface TVOSViewController () <UITableViewDelegate, UITableViewDataSource>
@property (strong, nonatomic) NSArray *dataSource;
@end

@implementation TVOSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _dataSource = @[
        @{
            @"sectionTitle": @"UUID",
            @"sectionRows": @[
                    @{
                        @"title": @"Get",
                        @"action": ^{
                            NSString *uuid = [[TreasureData sharedInstance] getUUID];
                            [self alertWithTitle:@"UUID" andMessage:uuid];
                        }
                    },
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableAutoAppendUniqId]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendUniqId]; }
                    },
                    @{
                        @"title": @"Reset",
                        @"action": ^{ [[TreasureData sharedInstance] resetUniqId]; }
                    },
            ]
        },
        @{
            @"sectionTitle": @"Auto Append Model Information",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableAutoAppendModelInformation]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendModelInformation]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Auto Append App Information",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableAutoAppendAppInformation]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendAppInformation]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Auto Append Local Information",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableAutoAppendLocaleInformation]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendLocaleInformation]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Server Side Upload Timestamp",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableServerSideUploadTimestamp]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableServerSideUploadTimestamp]; }
                    }
            ]
        }
    ];
    
    _tableView.dataSource = self;
    _tableView.delegate = self;
    
    [TVOSViewController setupTreasureData];
}

- (IBAction)addEventButtonClicked:(UIButton *)sender {
    NSDictionary *event = @{@"test_column": @"Test Value"};
//    [[TreasureData sharedInstance] addEvent:event table:@"tvos_table"];
    [[TreasureData sharedInstance] addEventWithCallback:event table:@"tvos_table" onSuccess:^{
        [self alertWithTitle:@"Event Added!" andMessage:nil];
    } onError:^(NSString * _Nonnull errorCode, NSString * _Nullable errorMessage) {
        [self alertWithTitle:@"Failed to add event!" andMessage:errorMessage];
    }];
}

- (IBAction)uploadEventButtonClicked:(UIButton *)sender {
//    [[TreasureData sharedInstance] uploadEvents];
    [[TreasureData sharedInstance] uploadEventsWithCallback:^{
        [self alertWithTitle:@"Event Uploaded!" andMessage:nil];
    } onError:^(NSString * _Nonnull errorCode, NSString * _Nullable errorMessage) {
        [self alertWithTitle:@"Failed to upload event!" andMessage:errorMessage];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [_dataSource count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_dataSource[section][@"sectionRows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _dataSource[section][@"sectionTitle"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell"];
    NSDictionary *row = _dataSource[indexPath.section][@"sectionRows"][indexPath.row];
    
    cell.textLabel.text = row[@"title"];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = _dataSource[indexPath.section][@"sectionRows"][indexPath.row];
    void(^action)(void) = row[@"action"];
    action();
}

#pragma mark - Helpers

- (void)alertWithTitle:(NSString *)title andMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }]];
        [self presentViewController:alertController animated:true completion:nil];
    });
}

#pragma MARK - Setup

+ (void)setupTreasureData {
    [TreasureData enableLogging];
    // [TreasureData initializeApiEndpoint:@"https://specify-other-endpoint-if-needed.com"];
    [TreasureData initializeEncryptionKey:@"encryption_key"];
    [TreasureData initializeWithApiKey:@"xxxxxxxxxxxxxxx"];
    [[TreasureData sharedInstance] setDefaultDatabase:@"default_db"];
    [[TreasureData sharedInstance] setDefaultTable:@"default_table"];
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
    [[TreasureData sharedInstance] enableAutoAppendRecordUUID];
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];
    [[TreasureData sharedInstance] enableAutoAppendAppInformation];
    [[TreasureData sharedInstance] enableAutoAppendLocaleInformation];
    [[TreasureData sharedInstance] enableServerSideUploadTimestamp:@"server_upload_time"];
    [[TreasureData sharedInstance] enableInAppPurchaseEvent];
    [[TreasureData sharedInstance] enableAutoAppendAdvertisingIdentifier:@"td_maid"];
}

@end
