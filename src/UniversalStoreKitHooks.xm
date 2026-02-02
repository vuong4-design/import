#import <Foundation/Foundation.h>

#import "UniversalStoreKitHooks.h"

%group UniversalStoreKitHooks

%end

extern "C" void InitUniversalStoreKitHooks() {
	NSLog(@"DEBUG* universal StoreKit hooks initialized");
	%init(UniversalStoreKitHooks);
}
