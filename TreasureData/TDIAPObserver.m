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
    [_td addEvent:[TDIAPObserver transactionToRecord:transaction] database:_td.defaultDatabase table:_td.defaultTable];
}

#pragma mark private

+ (NSDictionary *)transactionToRecord:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    NSString *requestData = @"";
    if (transaction.payment.requestData) {
         requestData = [[NSString alloc] initWithData:transaction.payment.requestData encoding:NSUTF8StringEncoding];
    }
    NSString *applicationUserName = transaction.payment.applicationUsername ? transaction.payment.applicationUsername : @"";

    return @{
        TD_COLUMN_EVENT: TD_EVENT_IAP_PURCHASED,
        @"td_transaction_identifier": transaction.transactionIdentifier,
        @"td_transaction_date": transaction.transactionDate,
        @"td_product_identifier": transaction.payment.productIdentifier,
        @"td_payment_quantity": @(transaction.payment.quantity),
        @"td_request_data": requestData,
        @"td_application_username": applicationUserName
    };

}

@end
