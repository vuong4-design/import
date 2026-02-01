#import <StoreKit/StoreKit.h>

#import "ObserverHooks.h"
#import "ObserverManager.h"

%group ObserverHooks

%hook SKPaymentQueue

- (void)addTransactionObserver:(id<SKPaymentTransactionObserver>)observer {
	static BOOL hasAddedRoutingObserver = NO;
	ObserverManager *manager = [ObserverManager sharedManager];
	if ([manager isRoutingObserver:observer]) {
		%orig(observer);
		return;
	}

	NSInteger priority = 10;
	if ([NSStringFromClass([observer class]) isEqualToString:@"VBStoreKitManager"]) {
		priority = 0;
	}

	[manager registerObserver:observer priority:priority];
	if (!hasAddedRoutingObserver) {
		hasAddedRoutingObserver = YES;
		%orig([manager routingObserver]);
	}
}

%end

%end

void InitObserverHooks(void) {
	NSLog(@"DEBUG* observer hooks initialized");
	%init(ObserverHooks);
}
