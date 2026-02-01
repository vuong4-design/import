#import "Foundation/Foundation.h"

#import "src/TweakManager.h"

%ctor {
	NSLog(@"DEBUG* import extension started!");
	[[TweakManager sharedManager] start];
}
