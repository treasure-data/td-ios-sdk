//
//  TDIAPObserver.h
//  TreasureData
//
//  Created by Huy TD on 3/11/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//

#import <StoreKit/StoreKit.h>

@class TreasureData;

@interface TDIAPObserver : NSObject <SKPaymentTransactionObserver>

@property BOOL enabled;

- (instancetype)initWithTD:(TreasureData *)td;

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;

@end
