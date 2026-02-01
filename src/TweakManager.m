#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

#import "TweakManager.h"
#import "Lineage2MImporter.h"
#import "ArknightsImporter.h"
#import "LineageMLiveImporter.h"
#import "SnailImporter.h"
#import "DynamicObserverHooks.h"
#import "LazyInitHooks.h"
#import "ObserverHooks.h"
#import "NetworkFallbackHooks.h"
#import "UniversalStoreKitHooks.h"

static NSString *const kConfigEnableForAllAppsKey = @"EnableForAllApps";
static NSString *const kConfigWhitelistedBundleIDsKey = @"WhitelistedBundleIDs";
static NSString *const kConfigLastLoadedPathKey = @"_LoadedFrom";
static NSString *const kFeatureHasIAPKey = @"import_feature_has_iap";
static NSString *const kFeatureCheckedKey = @"import_feature_checked";

typedef void (^FeatureCheckCompletion)(BOOL hasIAP);

@interface FeatureCheckDelegate : NSObject <SKProductsRequestDelegate>
@property (nonatomic, copy) FeatureCheckCompletion completion;
@end

@interface TweakManager ()
@property (nonatomic, assign) BOOL hasStarted;
@property (nonatomic, assign) BOOL hasInitializedHooks;
@property (nonatomic, assign) BOOL shouldInitializeHooks;
@property (nonatomic, assign) BOOL isCheckingFeatures;
@property (nonatomic, strong) SKProductsRequest *featureRequest;
@property (nonatomic, strong) FeatureCheckDelegate *featureDelegate;
@property (nonatomic, copy) NSDictionary *config;
@property (nonatomic, weak) UIWindow *lastKeyWindow;
@end

@implementation FeatureCheckDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	BOOL hasProducts = (response.products.count > 0);
	if (self.completion) {
		self.completion(hasProducts);
	}
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
	NSLog(@"DEBUG* feature check failed: %@", error.localizedDescription);
	if (self.completion) {
		self.completion(NO);
	}
}

- (void)requestDidFinish:(SKRequest *)request {
	// No-op; handled in productsRequest
}

@end

@implementation TweakManager

+ (instancetype)sharedManager {
	static TweakManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[TweakManager alloc] init];
	});
	return sharedInstance;
}

- (void)start {
	if (self.hasStarted) {
		return;
	}
	self.hasStarted = YES;
	self.config = [self loadConfiguration];

	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"(unknown)";
	if (![self shouldEnableForBundleID:bundleIdentifier]) {
		NSLog(@"DEBUG* import disabled for bundle: %@", bundleIdentifier);
		return;
	}

	NSLog(@"DEBUG* import enabled for bundle: %@", bundleIdentifier);
	[[NSNotificationCenter defaultCenter] addObserver:self
										 selector:@selector(windowDidBecomeKey:)
										 name:UIWindowDidBecomeKeyNotification
									 object:nil];
	InitLazyInitHooks();
}

- (NSDictionary *)loadConfiguration {
	NSDictionary *defaults = @{
		kConfigEnableForAllAppsKey: @YES,
		kConfigWhitelistedBundleIDsKey: @[],
	};

	NSString *preferencePath = @"/var/mobile/Library/Preferences/com.import.config.plist";
	NSString *appSupportPath = @"/Library/Application Support/import/Config.plist";
	NSString *bundleConfigPath = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
	NSDictionary *config = nil;
	NSString *loadedPath = nil;

	if ([[NSFileManager defaultManager] fileExistsAtPath:preferencePath]) {
		config = [NSDictionary dictionaryWithContentsOfFile:preferencePath];
		loadedPath = preferencePath;
	} else if ([[NSFileManager defaultManager] fileExistsAtPath:appSupportPath]) {
		config = [NSDictionary dictionaryWithContentsOfFile:appSupportPath];
		loadedPath = appSupportPath;
	} else if (bundleConfigPath.length > 0 &&
			 [[NSFileManager defaultManager] fileExistsAtPath:bundleConfigPath]) {
		config = [NSDictionary dictionaryWithContentsOfFile:bundleConfigPath];
		loadedPath = bundleConfigPath;
	}

	if (![config isKindOfClass:[NSDictionary class]]) {
		config = defaults;
		loadedPath = @"defaults";
	}

	NSMutableDictionary *finalConfig = [defaults mutableCopy];
	[finalConfig addEntriesFromDictionary:config];
	finalConfig[kConfigLastLoadedPathKey] = loadedPath;

	NSLog(@"DEBUG* import config loaded from %@", loadedPath);
	return [finalConfig copy];
}

- (BOOL)shouldEnableForBundleID:(NSString *)bundleIdentifier {
	if (![bundleIdentifier isKindOfClass:[NSString class]]) {
		return NO;
	}

	NSNumber *enableForAllApps = self.config[kConfigEnableForAllAppsKey];
	if ([enableForAllApps respondsToSelector:@selector(boolValue)] && enableForAllApps.boolValue) {
		return YES;
	}

	NSArray *whitelist = self.config[kConfigWhitelistedBundleIDsKey];
	if (![whitelist isKindOfClass:[NSArray class]] || whitelist.count == 0) {
		NSLog(@"DEBUG* import whitelist empty; skipping bundle filtering for %@", bundleIdentifier);
		return YES;
	}

	return [whitelist containsObject:bundleIdentifier];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
	if (self.hasInitializedHooks) {
		return;
	}
	UIWindow *window = notification.object;
	if ([window isKindOfClass:[UIWindow class]]) {
		self.lastKeyWindow = window;
	}
	if (self.shouldInitializeHooks) {
		[self attemptInitializeWithRetry:0 delay:0.1];
	}
}

- (void)requestInitializeHooks {
	if (self.hasInitializedHooks) {
		return;
	}
	if (self.shouldInitializeHooks) {
		return;
	}
	[self detectIAPWithCompletion:^(BOOL hasIAP) {
		if (!hasIAP) {
			NSLog(@"DEBUG* feature check: no IAP detected, skipping hooks");
			return;
		}
		self.shouldInitializeHooks = YES;
		[self attemptInitializeWithRetry:0 delay:0.1];
	}];
}

- (void)attemptInitializeWithRetry:(NSUInteger)attempt delay:(NSTimeInterval)delay {
	if (self.hasInitializedHooks) {
		return;
	}
	if (!self.shouldInitializeHooks) {
		return;
	}

	if ([self isUIReady]) {
		[self initializeHooks];
		return;
	}

	if (attempt >= 5) {
		NSLog(@"DEBUG* import UI not ready after retries; skipping init");
		return;
	}

	NSTimeInterval nextDelay = delay * 2.0;
	NSLog(@"DEBUG* import UI not ready (attempt %lu). retry in %.2fs",
		(unsigned long)attempt + 1,
		nextDelay);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(nextDelay * NSEC_PER_SEC)),
				dispatch_get_main_queue(), ^{
					[self attemptInitializeWithRetry:attempt + 1 delay:nextDelay];
				});
}

- (void)detectIAPWithCompletion:(FeatureCheckCompletion)completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:kFeatureCheckedKey]) {
		BOOL cachedValue = [defaults boolForKey:kFeatureHasIAPKey];
		if (completion) {
			completion(cachedValue);
		}
		return;
	}

	if (self.isCheckingFeatures) {
		return;
	}
	self.isCheckingFeatures = YES;

	NSSet<NSString *> *productIDs = [NSSet setWithObject:@"com.import.dummy"];
	SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
	FeatureCheckDelegate *delegate = [[FeatureCheckDelegate alloc] init];
	delegate.completion = ^(BOOL hasIAP) {
		NSUserDefaults *innerDefaults = [NSUserDefaults standardUserDefaults];
		[innerDefaults setBool:YES forKey:kFeatureCheckedKey];
		[innerDefaults setBool:hasIAP forKey:kFeatureHasIAPKey];
		[innerDefaults synchronize];
		self.isCheckingFeatures = NO;
		self.featureRequest = nil;
		self.featureDelegate = nil;
		if (completion) {
			completion(hasIAP);
		}
	};
	request.delegate = delegate;
	self.featureRequest = request;
	self.featureDelegate = delegate;
	[request start];
}

- (BOOL)isUIReady {
	UIWindow *keyWindow = self.lastKeyWindow ?: [self currentKeyWindow];
	if (![self isWindowReady:keyWindow]) {
		return NO;
	}
	return YES;
}

- (BOOL)isWindowReady:(UIWindow *)window {
	if (![window isKindOfClass:[UIWindow class]]) {
		return NO;
	}
	if (window.rootViewController == nil) {
		return NO;
	}
	return YES;
}

- (UIWindow *)currentKeyWindow {
	UIApplication *application = [UIApplication sharedApplication];
	if (@available(iOS 13.0, *)) {
		for (UIScene *scene in application.connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) {
				continue;
			}
			UIWindowScene *windowScene = (UIWindowScene *)scene;
			for (UIWindow *window in windowScene.windows) {
				if (window.isKeyWindow) {
					return window;
				}
			}
		}
	}
	return application.keyWindow;
}

- (void)initializeHooks {
	if (self.hasInitializedHooks) {
		return;
	}
	self.hasInitializedHooks = YES;

	NSLog(@"DEBUG* import initializing hooks");
	[[NSNotificationCenter defaultCenter] removeObserver:self
																									name:UIWindowDidBecomeKeyNotification
																								object:nil];
	InitDynamicObserverHooks();
	InitObserverHooks();
	InitNetworkFallbackHooks();
	InitUniversalStoreKitHooks();
	InitLineage2MImporter();
	InitArknightsImporter();
	InitLineageMLiveImporter();
	InitSnailImporter();
}

@end
