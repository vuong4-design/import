#import "ObserverManager.h"

@implementation ObserverManager

+ (instancetype)shared {
    static ObserverManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[ObserverManager alloc] init];
        instance.appObservers = [NSMutableArray array];
    });
    return instance;
}

- (void)trackObserver:(id<SKPaymentTransactionObserver>)observer {
    // Don't track our own observer if passed accidentally, though we handle primary separately
    if ([observer isKindOfClass:[VBStoreKitManager class]] || [observer isKindOfClass:[ObserverManager class]]) {
        if ([observer isKindOfClass:[VBStoreKitManager class]]) {
             self.primaryObserver = (VBStoreKitManager *)observer;
        }
        return;
    }
    
    // Validate object
    if (!observer) return;

    // Use pointer comparison or standard equality
    if (![self.appObservers containsObject:observer]) {
        // Weak reference might be better but for now strong as in plan
        [self.appObservers addObject:observer];
        NSLog(@"DEBUG* [ObserverManager] Tracking: %@", NSStringFromClass([observer class]));
    }
}

- (void)removeObserver:(id<SKPaymentTransactionObserver>)observer {
    [self.appObservers removeObject:observer];
}

- (void)routeTransactions:(NSArray<SKPaymentTransaction *> *)transactions 
                  toQueue:(SKPaymentQueue *)queue {
    
    BOOL exportMode = [ExportManager shared].exportMode;
    
    // Ensure primary observer exists
    if (!self.primaryObserver) {
        self.primaryObserver = [[VBStoreKitManager alloc] init];
    }
    
    if (exportMode) {
        // Export mode: ONLY VBStoreKitManager handles
        NSLog(@"DEBUG* [ObserverManager] Export mode - routing to VBStoreKitManager only");
        [self.primaryObserver paymentQueue:queue updatedTransactions:transactions];
        
        // Block app observers by NOT calling them
        return;
    }
    
    // Import mode: VBStoreKitManager handles first, then app observers
    NSLog(@"DEBUG* [ObserverManager] Import mode - routing to all observers");
    
    // Our observer first
    [self.primaryObserver paymentQueue:queue updatedTransactions:transactions];
    
    // Then let app observers handle (for normal app functionality)
    // We iterate a copy to avoid mutation issues during enumeration if something removes observer
    NSArray *observers = [self.appObservers copy];
    for (id<SKPaymentTransactionObserver> observer in observers) {
        if ([observer respondsToSelector:@selector(paymentQueue:updatedTransactions:)]) {
            [observer paymentQueue:queue updatedTransactions:transactions];
        }
    }
}

@end
