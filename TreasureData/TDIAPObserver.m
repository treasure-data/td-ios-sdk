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


@interface TDProductRequester : NSObject <SKProductsRequestDelegate>

- (instancetype)initWithProductIdentifier:(NSString *)productID observer:(TDIAPObserver *)observer;
- (void)start;
- (void)stop;

@end


@interface TDIAPObserver ()

- (void)flushTransactionOfProduct:(SKProduct *)product;

@property (atomic) NSDictionary<NSString *, SKProduct *> *productsCache;
// Transactions waiting for after full product information is fetched to record, keyed by product ID
@property (atomic) NSDictionary<NSString *, NSArray<SKPaymentTransaction *> *> *pendingTransactions;
// Requests for products information, also keyed by product ID
@property (atomic) NSDictionary<NSString *, NSArray<SKPaymentTransaction *> *> *pendingProductRequesters;

@end

@implementation TDIAPObserver {
    TreasureData * __weak _td;
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
        // We only track PURCHASED transaction
        if (transaction.transactionState != SKPaymentTransactionStatePurchased) continue;

        NSString *productID = transaction.payment.productIdentifier;
        SKProduct *cachedProduct = _productsCache[productID];
        if (cachedProduct) {
            [self addTransactionEvent:transaction product:cachedProduct];
        } else {
            NSMutableDictionary *pendingTransactions = [NSMutableDictionary dictionaryWithDictionary:self.pendingTransactions];
            if (!pendingTransactions[productID]) {
                pendingTransactions[productID] = [NSMutableSet new];
            }
            [pendingTransactions[productID] addObject:transaction];
            self.pendingTransactions = [NSDictionary dictionaryWithDictionary:pendingTransactions];

            [[[TDProductRequester alloc] initWithProductIdentifier:productID observer:self] start];
        }
    }
}

- (void)flushTransactionOfProduct:(SKProduct *)product {
    NSArray<SKPaymentTransaction *> *transactions = self.pendingTransactions[product.productIdentifier];
    if (transactions) {
        // Pop the processing transaction out of the pending ones
        NSMutableDictionary<NSString *, SKPaymentTransaction *> *remainTransactions = [NSMutableDictionary dictionaryWithDictionary:self.pendingTransactions];
        [remainTransactions removeObjectForKey:product.productIdentifier];
        self.pendingTransactions = [NSDictionary dictionaryWithDictionary:remainTransactions];

        // Update products cache
        NSMutableDictionary<NSString *, SKProduct *> *updateProductsCache = [NSMutableDictionary dictionaryWithDictionary:self.productsCache];
        updateProductsCache[product.productIdentifier] = product;
        self.productsCache = [NSDictionary dictionaryWithDictionary:updateProductsCache];

        for (SKPaymentTransaction *transaction in transactions) {
            [self addTransactionEvent:transaction product:product];
        }
    }
    else {
        // Another TDProductRequester might flush transactions of this product already
    }
}

- (void)addTransactionEvent:(SKPaymentTransaction *)transaction product:(SKProduct *)product {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
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

    [_td addEvent:[TDIAPObserver transactionToEvent:transaction product:product] database:targetDatabase table:targetTable];
}

+ (NSDictionary *)transactionToEvent:(SKPaymentTransaction *)transaction product:(SKProduct *)product {
    if (product) {
        // On earlier versions than iOS 10.0, we leave the currency code empty
        id currencyCode = [NSNull null];
        if (@available(iOS 10.0, *)) {
            currencyCode = product.priceLocale.currencyCode;
        }

        return [TDUtils
                markAsIAPEvent:@{TD_COLUMN_EVENT: TD_EVENT_IAP_PURCHASE,
                                 @"td_iap_transaction_identifier": transaction.transactionIdentifier,
                                 @"td_iap_transaction_date": transaction.transactionDate,
                                 @"td_iap_product_identifier": transaction.payment.productIdentifier,
                                 @"td_iap_product_price": product.price,
                                 @"td_iap_product_localized_title": product.localizedTitle ?: [NSNull null],
                                 @"td_iap_product_localized_description": product.localizedDescription ?: [NSNull null],
                                 @"td_iap_product_currency_code": currencyCode,
                                 @"td_iap_quantity": @(transaction.payment.quantity),
                                 }];

    } else {
        return [TDUtils
                markAsIAPEvent:@{TD_COLUMN_EVENT: TD_EVENT_IAP_PURCHASE,
                                 @"td_iap_transaction_identifier": transaction.transactionIdentifier,
                                 @"td_iap_transaction_date": transaction.transactionDate,
                                 @"td_iap_product_identifier": transaction.payment.productIdentifier,
                                 @"td_iap_quantity": @(transaction.payment.quantity),
                                 }];

    }
}

@end


@implementation TDProductRequester {
    NSString *_productID;
    TDIAPObserver * __weak _observer;
}

- (instancetype)initWithProductIdentifier:(NSString *)productID observer:(TDIAPObserver *)observer {
    self = [super init];
    if (self) {
        _productID = productID;
        _observer = observer;

        // Retain self
        NSMutableDictionary *requestHandlers = [NSMutableDictionary dictionaryWithDictionary:_observer.pendingProductRequesters];
        requestHandlers[productID] = self;
        _observer.pendingProductRequesters = [NSDictionary dictionaryWithDictionary:requestHandlers];
    }
    return self;
}

- (void)start {
    NSSet *productIDs = [NSSet setWithArray:@[_productID]];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
    productsRequest.delegate = self;
    [productsRequest start];
}

- (void)stop {
    NSMutableDictionary *requestHandlers = [NSMutableDictionary dictionaryWithDictionary:_observer.pendingProductRequesters];
    requestHandlers[_productID] = nil;
    _observer.pendingProductRequesters = [NSDictionary dictionaryWithDictionary:requestHandlers];
}


- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
    SKProduct *product = response.products[0];  // we always request for a single product
    [_observer flushTransactionOfProduct:product];
    [self stop];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    // Still flush the transaction with empty product information (except product ID)
    [_observer flushTransactionOfProduct:nil];
    [self stop];
}

@end
