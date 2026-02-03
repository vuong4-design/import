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
    NSString *className = NSStringFromClass([observer class]);
    NSLog(@"DEBUG* [Universal] App registered observer: %@", className);
    
    // Track observer for later use
    [[ObserverManager shared] trackObserver:observer];
    
    %orig;
}

- (void)removeTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
    NSLog(@"DEBUG* [Universal] App removed observer: %@", 
          NSStringFromClass([observer class]));
    
    [[ObserverManager shared] removeObserver:observer];
    %orig;
}

// Intercept transactions and route them
- (void)setTransactions:(NSArray *)transactions {
    // This is internal, but we want to intercept 'updatedTransactions' calls usually.
    // The SKPaymentQueue calls observers. We want to intercept that call.
    // However, since we track observers, we can just intercept the primary transaction handling if possible.
    // Or we can try to hook `paymentQueue:updatedTransactions:` on the *observers* themselves?
    // BUT we don't know the observer classes at compile time easily.
    // CONSTANT EXCEPTION: We hook `SKPaymentQueue`'s internal method that notifies observers? 
    // OR we act as a proxy observer?
    
    // STRATEGY: 
    // 1. We inject OUR observer (VBStoreKitManager) via defaultQueue.
    // 2. We hook observer registration to keeping track of others.
    // BUT SKPaymentQueue will notify ALL observers. We cannot easily "block" others unless we remove them or hook their callback.
    // Hooking the callback dynamically is what Phase 3 original plan (DynamicHooker) was.
    // 
    // "UniversalStoreKitHooks" plan logic said:
    // "Universal->>Observer: routeTransactions()"
    // AND "Import mode: Observer->>VB: handle, Observer->>App: let app handle".
    // 
    // To achieve "BLOCKING" app observers in Export Mode, we MUST ensure the App Observers DO NOT receive the call from SKPaymentQueue directly.
    // If SKPaymentQueue holds them, it calls them.
    // 
    // FIX: SWIZZLE `addTransactionObserver:` to NOT actually add them to SKPaymentQueue if we want full control?
    // OR: We add them to our ObserverManager, but passed `nil` or `self` (proxy) to real SKPaymentQueue?
    // If we don't add them to SKPaymentQueue, they get nothing. We (ObserverManager) get events, then forward to them manually.
    // 
    // REVISED STRATEGY for `addTransactionObserver:`
    // 1. When App calls `addTransactionObserver:realObserver`:
    //    - We call `[[ObserverManager shared] trackObserver:realObserver]`.
    //    - We DO NOT call `%orig` (so realObserver is NOT added to StoreKit).
    // 2. We ensure `ObserverManager` (or VBStoreKitManager) IS added to StoreKit (once).
    // 3. When StoreKit callbacks our observer, ObserverManager routes to `realObserver` if needed.
    
    NSString *className = NSStringFromClass([observer class]);
    
    if ([observer isKindOfClass:[VBStoreKitManager class]] || [observer isKindOfClass:[ObserverManager class]]) {
        // Allow our managers to register real
        %orig;
    } else {
        // Hijack: Capture observer, but DON'T let StoreKit parse it directly.
        // Wait, if we don't let StoreKit have it, we must ensure we proxy ALL methods (paymentQueue:removedTransactions:, etc).
        // SKPaymentTransactionObserver has optional methods.
        
        NSLog(@"DEBUG* [Universal] Hijacking observer: %@", className);
        [[ObserverManager shared] trackObserver:observer];
        
        // We do NOT call %orig here, effectively hiding transactions from the app
        // UNLESS we decide to forward them via ObserverManager.
    }
}

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
