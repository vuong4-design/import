#import <UIKit/UIKit.h>

#import "LazyInitHooks.h"
#import "TweakManager.h"

static BOOL ShouldTriggerForController(UIViewController *controller) {
	if (!controller) {
		return NO;
	}
	NSString *className = NSStringFromClass([controller class]);
	if (className.length == 0) {
		return NO;
	}
	NSString *lower = [className lowercaseString];
	return ([lower containsString:@"purchase"] ||
		[lower containsString:@"payment"] ||
		[lower containsString:@"subscribe"]);
}

%group LazyInitHooks

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig(animated);
	if (ShouldTriggerForController(self)) {
		NSLog(@"DEBUG* lazy init triggered by %@", NSStringFromClass([self class]));
		[[TweakManager sharedManager] requestInitializeHooks];
	}
}

%end

%end

void InitLazyInitHooks(void) {
	NSLog(@"DEBUG* lazy init hooks initialized");
	%init(LazyInitHooks);
}
