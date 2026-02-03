#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "../VBStoreKitManager.h"
#import "../ExportManager.h"

@interface ObserverManager : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, strong) NSMutableArray *appObservers;
@property (nonatomic, strong) VBStoreKitManager *primaryObserver;

+ (instancetype)shared;

// Track observers
- (void)trackObserver:(id<SKPaymentTransactionObserver>)observer;
- (void)removeObserver:(id<SKPaymentTransactionObserver>)observer;

// Transaction routing
- (void)routeTransactions:(NSArray<SKPaymentTransaction *> *)transactions 
                  toQueue:(SKPaymentQueue *)queue;

@end
