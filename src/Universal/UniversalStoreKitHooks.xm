#import <StoreKit/StoreKit.h>
#import "ObserverManager.h"
#import "ProductCollector.h"
#import "../Core/SafeInjectionManager.h"
#import "../VBStoreKitManager.h"

%group UniversalStoreKitHooks

// ============================================
// HOOK 1: Track ALL observers apps register
// ============================================
%hook SKPaymentQueue

- (void)addTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
    if (!observer) return;
    NSString *className = NSStringFromClass([observer class]);
    
    // Check if it's one of our internal observers
    if ([observer isKindOfClass:[VBStoreKitManager class]] || [observer isKindOfClass:[ObserverManager class]]) {
        // Allow our managers to register with the real StoreKit
        NSLog(@"DEBUG* [Universal] Registering internal observer: %@", className);
        %orig(observer);
    } else {
        // Hijack: Capture app's observer, but DON'T let StoreKit see it directly.
        // This ensures the app doesn't receive transaction updates directly from StoreKit.
        // Instead, ObserverManager will route transactions to it manually (if not in Export mode).
        
        NSLog(@"DEBUG* [Universal] Hijacking app observer: %@", className);
        [[ObserverManager shared] trackObserver:observer];
        
        // IMPORTANT: We do NOT call %orig here.
    }
}

- (void)removeTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
    NSLog(@"DEBUG* [Universal] App removed observer: %@", 
          NSStringFromClass([observer class]));
    
    [[ObserverManager shared] removeObserver:observer];
    %orig;
}

// Intercept transactions and route them


%end

// ============================================
// HOOK 2: Intercept ALL transactions via our observer
// ============================================
%hook SKPaymentQueue

+ (instancetype)defaultQueue {
    SKPaymentQueue *queue = %orig;
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Inject ObserverManager as the primary LISTENER
        // We use ObserverManager as it conforms to protocol in our header
        ObserverManager *manager = [ObserverManager shared];
        [queue addTransactionObserver:manager];
        NSLog(@"DEBUG* [Universal] ObserverManager injected as primary listener");
    });
    
    return queue;
}

%end

// ============================================
// HOOK 3: Capture ALL product requests
// ============================================
%hook SKProductsRequest

- (void)setDelegate:(id<SKProductsRequestDelegate>)delegate {
    NSLog(@"DEBUG* [Universal] SKProductsRequest delegate: %@", 
          NSStringFromClass([delegate class]));
    
    // We can wrap it or just log it. 
    // Since we hook SKProductsResponse below, we catch the data anyway.
    %orig;
}

- (void)start {
    NSLog(@"DEBUG* [Universal] SKProductsRequest started");
    %orig;
}

%end

// ============================================
// HOOK 4: Capture product response
// ============================================
%hook SKProductsResponse

- (NSArray<SKProduct *> *)products {
    NSArray *products = %orig;
    
    NSLog(@"DEBUG* [Universal] Got %lu products", (unsigned long)products.count);
    
    // Collect product info
    [[ProductCollector shared] collectProducts:products];
    
    return products;
}

%end

// ============================================
// HOOK 5: UI Injection
// ============================================
%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Wait a bit for app to fully load
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 
            (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [[SafeInjectionManager shared] injectUIIfNeeded];
        });
    });
}

%end

%end // UniversalStoreKitHooks group

// ============================================
// INITIALIZATION
// ============================================
extern "C" void InitUniversalStoreKitHooks() {
    NSLog(@"DEBUG* [Universal] Initializing Universal StoreKit Hooks");
    %init(UniversalStoreKitHooks);
}
