#import "Foundation/Foundation.h"
#import "src/Core/TweakManager.h"

// Universal hooks - NO app-specific imports needed!
extern "C" void InitUniversalStoreKitHooks(void);

%ctor {
	@autoreleasepool {
		NSLog(@"DEBUG* Import Tweak Loaded");

		// Check iOS version
		if (@available(iOS 13.0, *)) {
            // Good
        } else {
			NSLog(@"DEBUG* iOS version too low, skipping");
			return;
		}

		NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

		// Check whitelist via TweakManager
		if (![[TweakManager shared] shouldEnableForBundle:bundleID]) {
			// Uncomment next line to debug if whitelist works
			// NSLog(@"DEBUG* Bundle %@ not in whitelist, skipping", bundleID);
			return;
		}

		NSLog(@"DEBUG* Import tweak starting for %@", bundleID);

		// Initialize UNIVERSAL hooks - works for ALL apps!
		InitUniversalStoreKitHooks();
        
        // Mark as initialized in TweakManager
        [[TweakManager shared] initializeWithBundleID:bundleID];

		NSLog(@"DEBUG* Universal StoreKit hooks initialized");
	}
}
