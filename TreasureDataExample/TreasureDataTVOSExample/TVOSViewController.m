//
//  ViewController.m
//  TreasureDataTVOSExample
//
//  Created by Tung Vu on 10/16/20.
//  Copyright © 2020 Treasure Data. All rights reserved.
//

@import StoreKit;
#import "TVOSViewController.h"
#import "TreasureData.h"
#import "TextFieldTableViewCell.h"

@interface TVOSViewController () <UITableViewDelegate, UITableViewDataSource, SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property (strong, nonatomic) NSString *defaultTable;
@property (strong, nonatomic) NSString *defaultDatabase;
@property (strong, nonatomic) NSString *encryptionKey;
@property (strong, nonatomic) NSString *apiKey;
@property (strong, nonatomic) NSString *eventTable;
@property (strong, nonatomic) NSString *eventDatabase;
@property (strong, nonatomic) NSArray *dataSource;
@property (strong, nonatomic) NSString *serverSideUploadTimestampColumnName;
@property (strong, nonatomic) NSString *recordUUIDColumnName;
@property (strong, nonatomic) NSString *aaidColumnName;
@property (strong, nonatomic) NSString *sessionTable;
@property (strong, nonatomic) NSString *sessionDatabase;
@property (strong, nonatomic) NSArray *audienceTokens;
@property (strong, nonatomic) NSDictionary *audienceKeys;
@property (strong, nonatomic) SKProductsRequest *productRequest;
@end

@implementation TVOSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.defaultDatabase = @"default_db";
    self.defaultTable = @"default_table";
    self.eventDatabase = @"event_db";
    self.eventTable = @"event_table";
    self.encryptionKey = @"encryption_key";
    self.apiKey = @"xxxxxx";
    self.audienceTokens = @[@"xxxx", @"xxxxx"];
    self.audienceKeys = @{@"key1": @"value2", @"key2": @"value2"};
    
    _dataSource = @[];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    
    [self setupTreasureData];
    [self reloadData];
}

- (void)reloadData {
    _dataSource = @[
        @{
            @"sectionTitle": @"Event",
            @"sectionRows": @[
                    @{
                        @"type": @"TextInput",
                        @"title": @"Event table",
                        @"value": _eventTable ?: @"",
                        @"action": ^(NSString *text) {
                            self.eventTable = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"type": @"TextInput",
                        @"title": @"Event database",
                        @"value": _eventDatabase ?: @"",
                        @"action": ^(NSString *text) {
                            self.eventDatabase = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"title": @"Add",
                        @"action": ^{ [self addEvent]; }
                    },
                    @{
                        @"title": @"Upload",
                        @"action": ^{ [self uploadEvent]; }
                    }
            ]
        },
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
                        @"type": @"TextInput",
                        @"title": @"Column",
                        @"value": _serverSideUploadTimestampColumnName ?: @"",
                        @"action": ^(NSString *text) {
                            self.serverSideUploadTimestampColumnName = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"title": @"Enable",
                        @"action": ^{
                            if (self.serverSideUploadTimestampColumnName != nil && ![self.serverSideUploadTimestampColumnName isEqual:@""]) {
                                [[TreasureData sharedInstance] enableServerSideUploadTimestamp: self.serverSideUploadTimestampColumnName];
                            } else {
                                [[TreasureData sharedInstance] enableServerSideUploadTimestamp];
                            }
                        }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableServerSideUploadTimestamp]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Auto Append Record UUID",
            @"sectionRows": @[
                    @{
                        @"type": @"TextInput",
                        @"title": @"Column name",
                        @"value": _recordUUIDColumnName ?: @"",
                        @"action": ^(NSString *text) {
                            self.recordUUIDColumnName = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"title": @"Enable",
                        @"action": ^{
                            if (self.recordUUIDColumnName != nil && ![self.recordUUIDColumnName isEqual:@""]) {
                                [[TreasureData sharedInstance] enableAutoAppendRecordUUID: self.recordUUIDColumnName];
                            } else {
                                [[TreasureData sharedInstance] enableAutoAppendRecordUUID];
                            }
                        }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendRecordUUID]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Auto Append Advertising Identifier",
            @"sectionRows": @[
                    @{
                        @"type": @"TextInput",
                        @"title": @"Column name",
                        @"value": _aaidColumnName ?: @"",
                        @"action": ^(NSString *text) {
                            self.aaidColumnName = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"title": @"Enable",
                        @"action": ^{
                            if (self.aaidColumnName != nil && ![self.aaidColumnName isEqual:@""]) {
                                [[TreasureData sharedInstance] enableAutoAppendAdvertisingIdentifier: self.aaidColumnName];
                            } else {
                                [[TreasureData sharedInstance] enableAutoAppendAdvertisingIdentifier];
                            }
                        }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAutoAppendAdvertisingIdentifier]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Session",
            @"sectionRows": @[
                    @{
                        @"type": @"TextInput",
                        @"title": @"Session table",
                        @"value": _sessionTable ?: @"",
                        @"action": ^(NSString *text) {
                            self.sessionTable = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"type": @"TextInput",
                        @"title": @"Session database",
                        @"value": _sessionDatabase ?: @"",
                        @"action": ^(NSString *text) {
                            self.sessionDatabase = text;
                            [self reloadData];
                        }
                    },
                    @{
                        @"title": @"Get session id",
                        @"action": ^{
                            NSString *sessionId = [[TreasureData sharedInstance] getSessionId];
                            [self alertWithTitle:@"Session id" andMessage:sessionId];
                        }
                    },
                    @{
                        @"title": @"Start session",
                        @"action": ^{
                            if (self.sessionDatabase == nil || [self.sessionDatabase isEqual:@""]) {
                                [[TreasureData sharedInstance] startSession:self.sessionTable];
                            } else {
                                [[TreasureData sharedInstance] startSession:self.sessionTable database:self.sessionDatabase];
                            }
                        }
                    },
                    @{
                        @"title": @"End session",
                        @"action": ^{
                            if (self.sessionDatabase == nil || [self.sessionDatabase isEqual:@""]) {
                                [[TreasureData sharedInstance] endSession:self.sessionTable];
                            } else {
                                [[TreasureData sharedInstance] endSession:self.sessionTable database:self.sessionDatabase];
                            }
                        }
                    },
                    @{
                        @"title": @"Get global session id",
                        @"action": ^{
                            NSString *globalSessionId = [TreasureData getSessionId];
                            [self alertWithTitle:@"Global session id" andMessage:globalSessionId];
                        }
                    },
                    @{
                        @"title": @"Start global session",
                        @"action": ^{ [TreasureData startSession]; }
                    },
                    @{
                        @"title": @"End global session",
                        @"action": ^{ [TreasureData endSession]; }
                    },
                    @{
                        @"title": @"Set timeout milli",
                        @"action": ^(NSString *text) { [TreasureData setSessionTimeoutMilli:20000]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Custom Event",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableCustomEvent]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableCustomEvent]; }
                    },
                    @{
                        @"title": @"Is enabled?",
                        @"action": ^{
                            NSString *isCustomEventEnabled = [[TreasureData sharedInstance] isCustomEventEnabled] ? @"YES" : @"NO";
                            [self alertWithTitle:@"Is custom event enabled?" andMessage:isCustomEventEnabled];
                        }
                    }
            ]
        },
        @{
            @"sectionTitle": @"App Lifecycle",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableAppLifecycleEvent]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableAppLifecycleEvent]; }
                    },
                    @{
                        @"title": @"Is enabled?",
                        @"action": ^{
                            NSString *isAppLifecycleEventEnabled = [[TreasureData sharedInstance] isAppLifecycleEventEnabled] ? @"YES" : @"NO";
                            [self alertWithTitle:@"Is app lifecycle event enabled?" andMessage:isAppLifecycleEventEnabled];
                        }
                    }
            ]
        },
        @{
            @"sectionTitle": @"IAP Event",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableInAppPurchaseEvent]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableInAppPurchaseEvent]; }
                    },
                    @{
                        @"title": @"Is enabled?",
                        @"action": ^{
                            NSString *isInAppPurchaseEventEnabled = [[TreasureData sharedInstance] isInAppPurchaseEventEnabled] ? @"YES" : @"NO";
                            [self alertWithTitle:@"Is IAP event enabled?" andMessage:isInAppPurchaseEventEnabled];
                        }
                    },
                    @{
                        @"title": @"Purchase",
                        @"action": ^{ [self purchase]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Profile API",
            @"sectionRows": @[
                    @{
                        @"title": @"Fetch user segments",
                        @"action": ^{
                            [[TreasureData sharedInstance] fetchUserSegments:self.audienceTokens keys:self.audienceKeys options:nil completionHandler:^(NSArray * _Nullable jsonResponse, NSError * _Nullable error) {
                                                            if (error != nil) {
                                                                [self alertWithTitle:@"Failed to fetch user segments!" andMessage:error.localizedDescription];
                                                            } else {
                                                                [self alertWithTitle:@"Fetch user segments successfully!" andMessage:[jsonResponse debugDescription]];
                                                            }
                            }];
                        }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Retry Uploading",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [[TreasureData sharedInstance] enableRetryUploading]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [[TreasureData sharedInstance] disableRetryUploading]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Event Compression",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [TreasureData enableEventCompression]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [TreasureData disableEventCompression]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"Retry Uploading",
            @"sectionRows": @[
                    @{
                        @"title": @"Enable",
                        @"action": ^{ [TreasureData enableLogging]; }
                    },
                    @{
                        @"title": @"Disable",
                        @"action": ^{ [TreasureData disableLogging]; }
                    }
            ]
        },
        @{
            @"sectionTitle": @"First Run",
            @"sectionRows": @[
                    @{
                        @"title": @"Is first run?",
                        @"action": ^{
                            NSString *isFirstRun = [[TreasureData sharedInstance] isFirstRun] ? @"YES" : @"NO";
                            [self alertWithTitle:@"Is first run?" andMessage:isFirstRun];
                        }
                    },
                    @{
                        @"title": @"Clear first run",
                        @"action": ^{ [[TreasureData sharedInstance] clearFirstRun]; }
                    }
            ]
        }
    ];
    [_tableView reloadData];
}

- (IBAction)addEventButtonClicked:(UIButton *)sender {
    [self addEvent];
}

- (IBAction)uploadEventButtonClicked:(UIButton *)sender {
    [self uploadEvent];
}

- (void)addEvent {
    NSDictionary *event = @{
        @"test_column": @"Test Value"
    };
    
    if (_eventTable == nil || [_eventTable isEqual:@""]) {
       [self alertWithTitle:@"Event table not specified!" andMessage:@"You must specify event table"];
    } else if (_eventDatabase == nil || [_eventDatabase isEqual:@""]) {
        [[TreasureData sharedInstance] addEventWithCallback:event table:_eventTable onSuccess:^{
            [self alertWithTitle:@"Event Added!" andMessage:nil];
        } onError:^(NSString * _Nonnull errorCode, NSString * _Nullable errorMessage) {
            [self alertWithTitle:@"Failed to add event!" andMessage:errorMessage];
        }];
    } else {
        [[TreasureData sharedInstance] addEventWithCallback:event database:_eventDatabase table:_eventTable onSuccess:^{
            [self alertWithTitle:@"Event Added!" andMessage:nil];
        } onError:^(NSString * _Nonnull errorCode, NSString * _Nullable errorMessage) {
            [self alertWithTitle:@"Failed to add event!" andMessage:errorMessage];
        }];
    }
}

- (void)uploadEvent {
    [[TreasureData sharedInstance] uploadEventsWithCallback:^{
        [self alertWithTitle:@"Event Uploaded!" andMessage:nil];
    } onError:^(NSString * _Nonnull errorCode, NSString * _Nullable errorMessage) {
        [self alertWithTitle:@"Failed to upload event!" andMessage:errorMessage];
    }];
}

- (void)purchase {
    NSLog(@"Purchasing IAP");
    NSSet *productIds = [NSSet setWithObjects:@"com.treasuredata.iaptest.consumable1", nil];
    _productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: productIds];
    _productRequest.delegate = self;
    [_productRequest start];
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
    NSDictionary *row = _dataSource[indexPath.section][@"sectionRows"][indexPath.row];

    if ([row[@"type"] isEqual: @"TextInput"]) {
        TextFieldTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TextFieldTableViewCell"];
        cell.textLabel.text = row[@"title"];
        cell.detailTextLabel.text = row[@"value"];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ActionCell"];
        cell.textLabel.text = row[@"title"];
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = _dataSource[indexPath.section][@"sectionRows"][indexPath.row];
    if ([row[@"type"] isEqual: @"TextInput"]) {
        TextFieldTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.onEndEditingBlock = row[@"action"];
        [cell.textField becomeFirstResponder];
    } else {
        void(^action)(void) = row[@"action"];
        action();
    }
    [tableView deselectRowAtIndexPath:indexPath animated:true];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"Fetched products");
    SKProduct *buyingProduct = response.products.firstObject;
    SKPayment *payment = [SKPayment paymentWithProduct:buyingProduct];
    [SKPaymentQueue.defaultQueue addTransactionObserver:self];
    [SKPaymentQueue.defaultQueue addPayment:payment];
}

- (void)requestDidFinish:(SKRequest *)request {
    NSLog(@"Fetch product request did finish");
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSLog(@"Failed to fetch products");
    [self alertWithTitle:@"Failed to purchase" andMessage:error.localizedDescription];
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self alertWithTitle:@"Purchased successfully" andMessage:@""];
                break;
            case SKPaymentTransactionStateDeferred:
                [self alertWithTitle:@"Purchase deferred" andMessage:@""];
                break;
            case SKPaymentTransactionStateRestored:
                [self alertWithTitle:@"Purchase restored" andMessage:@""];
            case SKPaymentTransactionStateFailed:
                [self alertWithTitle:@"Failed to purchase" andMessage:transaction.error.localizedDescription];
                break;
                
            default:
                break;
        }
    }
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

- (void)setupTreasureData {
    [TreasureData enableLogging];
    // [TreasureData initializeApiEndpoint:@"https://specify-other-endpoint-if-needed.com"];
    [TreasureData initializeEncryptionKey:_encryptionKey];
    [TreasureData initializeWithApiKey:_apiKey];
    [[TreasureData sharedInstance] setDefaultDatabase:_defaultDatabase];
    [[TreasureData sharedInstance] setDefaultTable:_defaultTable];
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
