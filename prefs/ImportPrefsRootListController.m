#import "ImportPrefsRootListController.h"

#import <Preferences/PSSpecifier.h>

static NSString *const kPreferencePath = @"/var/mobile/Library/Preferences/com.import.config.plist";

@implementation ImportPrefsRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kPreferencePath];
	if (![settings isKindOfClass:[NSDictionary class]]) {
		settings = @{};
	}
	id value = settings[specifier.properties[@"key"]];
	return value ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSMutableDictionary *settings = [[NSDictionary dictionaryWithContentsOfFile:kPreferencePath] mutableCopy];
	if (![settings isKindOfClass:[NSMutableDictionary class]]) {
		settings = [[NSMutableDictionary alloc] init];
	}
	NSString *key = specifier.properties[@"key"];
	if (key.length > 0) {
		settings[key] = value ?: [NSNull null];
		[settings writeToFile:kPreferencePath atomically:YES];
	}
}

- (void)resetConfiguration:(PSSpecifier *)specifier {
	(void)specifier;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:kPreferencePath]) {
		[fileManager removeItemAtPath:kPreferencePath error:nil];
	}
	[self reloadSpecifiers];
}

@end
