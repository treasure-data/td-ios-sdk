//
//  TDIAPObserver.m
//  TreasureData
//
//  Created by huylenq on 3/11/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//

// TODO: We moved most of the operation to a serial dispatch queue,
// it could be better to lift of some excessive immutable guards to reduce objects' allocation costs.

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

@property (atomic, strong) NSDictionary<NSString *, SKProduct *> *productsCache;
// Transactions waiting for after full product information is fetched to record, keyed by product ID
@property (atomic, strong) NSDictionary<NSString *, NSArray<SKPaymentTransaction *> *> *pendingTransactions;
// Requests for products information, also keyed by product ID
@property (atomic, strong) NSDictionary<NSString *, NSArray<SKPaymentTransaction *> *> *pendingProductRequesters;

@property (nonatomic, strong) dispatch_queue_t trackIAPQueue;

@end

@implementation TDIAPObserver {
    TreasureData * __weak _td;
}

- (instancetype)initWithTD:(TreasureData *)td {
    if (self = [super init]) {
        _td = td;
        self.trackIAPQueue = dispatch_queue_create("com.treasuredata.track_iap_queue", DISPATCH_QUEUE_SERIAL);

        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    dispatch_async(self.trackIAPQueue, ^{
        @try {
            for (SKPaymentTransaction* transaction in transactions) {
                // We only track PURCHASED transaction
                if (transaction.transactionState != SKPaymentTransactionStatePurchased) continue;

                NSString *productID = transaction.payment.productIdentifier;
                SKProduct *cachedProduct = self.productsCache[productID];
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
        @catch (NSException *exception) {
            NSLog(@"ERROR: Failed processing an IAP transaction. %@", exception);
        }
    });
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
    dispatch_async(_observer.trackIAPQueue, ^{
        @try {
            SKProduct *product = response.products[0];  // we always request for a single product
            [self->_observer flushTransactionOfProduct:product];
            [self stop];
        }
        @catch (NSException *exception) {
            NSLog(@"ERROR: Failed to track IAP transactions.");
        }
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(_observer.trackIAPQueue, ^{
        @try {
            KCLog(@"WARN: Unable to fetch a product, some transactions will be tracked without that product information.");
            // Still flush the transaction with empty product information (except product ID)
            [self->_observer flushTransactionOfProduct:nil];
            [self stop];
        }
        @catch (NSException *exception) {
            NSLog(@"ERROR: Failed to track IAP transactions.");
        }
    });
}

@end
