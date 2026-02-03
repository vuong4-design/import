#import "TweakManager.h"
#import "iOSVersionHelper.h"

@interface TweakManager ()
@property (nonatomic, strong) NSDictionary *config;
@end

@implementation TweakManager

+ (instancetype)shared {
    static TweakManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TweakManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadConfig];
    }
    return self;
}

- (void)loadConfig {
    NSString *configPath = @"/Library/MobileSubstrate/DynamicLibraries/import/Config.plist"; // Adjust path if needed for development vs production
    
    // For local dev where file might be in bundle
    if (![[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
        configPath = [[NSBundle mainBundle] pathForResource:@"Config" ofType:@"plist"];
    }
    
    // Fallback trying to find it relative to Tweak location if possible, or create default
    if (configPath && [[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
        self.config = [NSDictionary dictionaryWithContentsOfFile:configPath];
    } else {
        // Default unsafe config if file missing
        NSLog(@"DEBUG* [TweakManager] Config.plist not found, using default");
        self.config = @{
            @"EnabledBundleIDs": @[],
            @"EnableForAllApps": @(NO),
            @"MinIOSVersion": @"13.0"
        };
    }
}

- (BOOL)shouldEnableForBundle:(NSString *)bundleID {
    if (!bundleID) return NO;
    
    // Check iOS version
    NSString *minVersionStr = self.config[@"MinIOSVersion"];
    if (minVersionStr) {
        if ([[UIDevice currentDevice].systemVersion compare:minVersionStr options:NSNumericSearch] == NSOrderedAscending) {
            NSLog(@"DEBUG* [TweakManager] iOS version too low for %@", bundleID);
            return NO;
        }
    }

    if ([self.config[@"EnableForAllApps"] boolValue]) {
        return YES;
    }
    
    NSArray *enabledBundles = self.config[@"EnabledBundleIDs"];
    return [enabledBundles containsObject:bundleID];
}

- (void)initializeWithBundleID:(NSString *)bundleID {
    if ([self shouldEnableForBundle:bundleID]) {
        NSLog(@"DEBUG* [TweakManager] Initialized for %@", bundleID);
    }
}

@end
