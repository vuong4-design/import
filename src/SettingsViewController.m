#import "SettingsViewController.h"

#import "ExportManager.h"
#import "ObserverManager.h"

static NSString *const kConfigEnableForAllAppsKey = @"EnableForAllApps";
static NSString *const kConfigWhitelistedBundleIDsKey = @"WhitelistedBundleIDs";
static NSString *const kConfigEnableUniversalHooksKey = @"EnableUniversalHooks";

static NSString *const kPreferencePath = @"/var/mobile/Library/Preferences/com.import.config.plist";

@interface SettingsViewController ()
@property (nonatomic, strong) UISwitch *enableAllAppsSwitch;
@property (nonatomic, strong) UISwitch *enableCurrentAppSwitch;
@property (nonatomic, strong) UISwitch *enableUniversalHooksSwitch;
@property (nonatomic, strong) UITextView *debugTextView;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor whiteColor];
	self.title = @"Settings";

	UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[closeButton setTitle:@"Close" forState:UIControlStateNormal];
	[closeButton addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
	closeButton.frame = CGRectMake(10, 40, 80, 30);
	[self.view addSubview:closeButton];

	UILabel *enableAllLabel = [self labelWithText:@"Enable for all apps" frame:CGRectMake(20, 90, 240, 24)];
	[self.view addSubview:enableAllLabel];
	self.enableAllAppsSwitch = [self switchWithAction:@selector(enableAllAppsChanged:) frame:CGRectMake(260, 90, 60, 24)];
	[self.view addSubview:self.enableAllAppsSwitch];

	UILabel *enableCurrentLabel = [self labelWithText:@"Enable this app" frame:CGRectMake(20, 130, 240, 24)];
	[self.view addSubview:enableCurrentLabel];
	self.enableCurrentAppSwitch = [self switchWithAction:@selector(enableCurrentAppChanged:) frame:CGRectMake(260, 130, 60, 24)];
	[self.view addSubview:self.enableCurrentAppSwitch];

	UILabel *enableUniversalLabel = [self labelWithText:@"Universal hooks" frame:CGRectMake(20, 170, 240, 24)];
	[self.view addSubview:enableUniversalLabel];
	self.enableUniversalHooksSwitch = [self switchWithAction:@selector(enableUniversalHooksChanged:) frame:CGRectMake(260, 170, 60, 24)];
	[self.view addSubview:self.enableUniversalHooksSwitch];

	UIButton *clearCacheButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[clearCacheButton setTitle:@"Clear cache" forState:UIControlStateNormal];
	[clearCacheButton addTarget:self action:@selector(clearCacheTapped:) forControlEvents:UIControlEventTouchUpInside];
	clearCacheButton.frame = CGRectMake(20, 210, 120, 30);
	[self.view addSubview:clearCacheButton];

	UIButton *refreshLogsButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[refreshLogsButton setTitle:@"Refresh logs" forState:UIControlStateNormal];
	[refreshLogsButton addTarget:self action:@selector(refreshLogsTapped:) forControlEvents:UIControlEventTouchUpInside];
	refreshLogsButton.frame = CGRectMake(160, 210, 120, 30);
	[self.view addSubview:refreshLogsButton];

	self.debugTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 250, 320, 260)];
	self.debugTextView.editable = NO;
	self.debugTextView.layer.borderColor = [UIColor lightGrayColor].CGColor;
	self.debugTextView.layer.borderWidth = 1.0;
	[self.view addSubview:self.debugTextView];

	[self loadSettings];
	[self refreshDebugLogs];
}

- (UILabel *)labelWithText:(NSString *)text frame:(CGRect)frame {
	UILabel *label = [[UILabel alloc] initWithFrame:frame];
	label.text = text;
	label.font = [UIFont systemFontOfSize:14.0];
	return label;
}

- (UISwitch *)switchWithAction:(SEL)action frame:(CGRect)frame {
	UISwitch *toggle = [[UISwitch alloc] initWithFrame:frame];
	[toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
	return toggle;
}

- (void)closeTapped:(UIButton *)sender {
	(void)sender;
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)enableAllAppsChanged:(UISwitch *)sender {
	NSMutableDictionary *config = [[self loadConfig] mutableCopy];
	config[kConfigEnableForAllAppsKey] = @(sender.isOn);
	[self saveConfig:config];
}

- (void)enableCurrentAppChanged:(UISwitch *)sender {
	NSMutableDictionary *config = [[self loadConfig] mutableCopy];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
	NSMutableArray *whitelist = [config[kConfigWhitelistedBundleIDsKey] mutableCopy] ?: [[NSMutableArray alloc] init];
	if (sender.isOn) {
		if (bundleID.length > 0 && ![whitelist containsObject:bundleID]) {
			[whitelist addObject:bundleID];
		}
	} else {
		[whitelist removeObject:bundleID];
	}
	config[kConfigWhitelistedBundleIDsKey] = whitelist;
	[self saveConfig:config];
}

- (void)enableUniversalHooksChanged:(UISwitch *)sender {
	NSMutableDictionary *config = [[self loadConfig] mutableCopy];
	config[kConfigEnableUniversalHooksKey] = @(sender.isOn);
	[self saveConfig:config];
}

- (void)clearCacheTapped:(UIButton *)sender {
	(void)sender;
	[[ExportManager shared] clearCachedData];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:@"import_feature_has_iap"];
	[defaults removeObjectForKey:@"import_feature_checked"];
	[defaults synchronize];
	[self refreshDebugLogs];
}

- (void)refreshLogsTapped:(UIButton *)sender {
	(void)sender;
	[self refreshDebugLogs];
}

- (void)loadSettings {
	NSDictionary *config = [self loadConfig];
	NSNumber *enableAll = config[kConfigEnableForAllAppsKey] ?: @YES;
	NSNumber *enableUniversal = config[kConfigEnableUniversalHooksKey] ?: @YES;
	NSArray *whitelist = config[kConfigWhitelistedBundleIDsKey] ?: @[];
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";

	self.enableAllAppsSwitch.on = enableAll.boolValue;
	self.enableUniversalHooksSwitch.on = enableUniversal.boolValue;
	self.enableCurrentAppSwitch.on = (bundleID.length > 0 && [whitelist containsObject:bundleID]);
}

- (NSDictionary *)loadConfig {
	NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:kPreferencePath];
	if (![config isKindOfClass:[NSDictionary class]]) {
		config = @{
			kConfigEnableForAllAppsKey: @YES,
			kConfigWhitelistedBundleIDsKey: @[],
			kConfigEnableUniversalHooksKey: @YES,
		};
	}
	return config;
}

- (void)saveConfig:(NSDictionary *)config {
	[config writeToFile:kPreferencePath atomically:YES];
	[self refreshDebugLogs];
}

- (void)refreshDebugLogs {
	NSMutableString *logText = [[NSMutableString alloc] init];
	[logText appendString:@"Transaction History:\n"]; 
	for (NSDictionary *entry in [[ExportManager shared] transactionHistory]) {
		[logText appendFormat:@"%@ | %@ | %@ | %@\n",
			entry[@"type"] ?: @"",
			entry[@"productID"] ?: @"",
			entry[@"status"] ?: @"",
			entry[@"timestamp"] ?: @""];
	}

	[logText appendString:@"\nObservers:\n"]; 
	for (NSDictionary *observer in [[ObserverManager sharedManager] trackedObservers]) {
		[logText appendFormat:@"%@ | %@ | %@\n",
			observer[@"class"] ?: @"",
			observer[@"priority"] ?: @"",
			observer[@"timestamp"] ?: @""];
	}

	self.debugTextView.text = logText;
}

@end
