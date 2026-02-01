#import <StoreKit/StoreKit.h>

#import "ObserverHooks.h"
#import "ObserverManager.h"

%group ObserverHooks

%hook SKPaymentQueue

- (void)addTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
	[[ObserverManager sharedManager] trackObserver:observer];
	%orig(observer);
}

%end

%end

void InitObserverHooks(void) {
	NSLog(@"DEBUG* observer hooks initialized");
	%init(ObserverHooks);
}
