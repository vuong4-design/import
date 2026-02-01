#import <Foundation/Foundation.h>

%group UniversalStoreKitHooks

%end

extern "C" void InitUniversalStoreKitHooks() {
	NSLog(@"DEBUG* universal StoreKit hooks initialized");
	%init(UniversalStoreKitHooks);
}
