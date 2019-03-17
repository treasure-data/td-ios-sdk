//
//  TDIAPObserver.m
//  TreasureData
//
//  Created by huylenq on 3/11/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//

#import "TDIAPObserver.h"
#import "TreasureData.h"
#import "Constants.h"
#import "TDUtils.h"

@implementation TDIAPObserver {
    TreasureData* __weak _td;
}

- (instancetype)initWithTD:(TreasureData *)td {
    self = [super init];
    if (self) {
        _td = td;
    }
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction* transaction in transactions) {
        [self trackTransaction:transaction];
    }
}

- (void)trackTransaction:(SKPaymentTransaction *)transaction {
    // We only track PURCHASED transaction
    if (transaction.transactionState != SKPaymentTransactionStatePurchased) return;

    NSString *targetDatabase = [TDUtils requireNonBlank:_td.defaultDatabase
                                           defaultValue:TD_DEFAULT_DATABASE
                                                message:[NSString
                                                         stringWithFormat:@"WARN: defaultDatabase was not set. \"%@\" will be used as the target database for in-app purchase events.",
                                                         TD_DEFAULT_DATABASE]];
    NSString *targetTable = [TDUtils requireNonBlank:_td.defaultTable
                                        defaultValue:TD_DEFAULT_TABLE
                                             message:[NSString
                                                      stringWithFormat:@"WARN: defaultTable was not set. \"%@\" will be used as the target table for in-app purchase events.",
                                                      TD_DEFAULT_TABLE]];
    
    [_td addEvent:[TDIAPObserver transactionToEvent:transaction] database:targetDatabase table:targetTable];
}

#pragma mark private

+ (NSDictionary *)transactionToEvent:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    NSString *requestData = nil;
    if (transaction.payment.requestData) {
         requestData = [[NSString alloc] initWithData:transaction.payment.requestData encoding:NSUTF8StringEncoding];
    }
    NSString *applicationUsername = transaction.payment.applicationUsername;

    return [TDUtils
            markAsIAPEvent:@{TD_COLUMN_EVENT: TD_EVENT_IAP_PURCHASED,
                             @"td_transaction_identifier": transaction.transactionIdentifier,
                             @"td_transaction_date": transaction.transactionDate,
                             @"td_product_identifier": transaction.payment.productIdentifier,
                             @"td_payment_quantity": @(transaction.payment.quantity),
                             @"td_request_data": requestData != nil ? (id) requestData : [NSNull null],
                             @"td_application_username": applicationUsername != nil ? (id) applicationUsername : [NSNull null],
                             }];
}

@end
