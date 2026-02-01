#import "Foundation/Foundation.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

#import "src/TweakManager.h"

%ctor {
	NSLog(@"DEBUG* import extension started!");
	unsigned int classCount = 0;
	Class *classes = objc_copyClassList(&classCount);
	if (classes) {
		NSMutableArray<NSString *> *observerClasses = [[NSMutableArray alloc] init];
		for (unsigned int i = 0; i < classCount; i++) {
			Class cls = classes[i];
			if (!cls) {
				continue;
			}
			if (class_conformsToProtocol(cls, @protocol(SKPaymentTransactionObserver))) {
				[observerClasses addObject:NSStringFromClass(cls)];
			}
		}
		free(classes);
		NSLog(@"DEBUG* SKPaymentTransactionObserver classes: %@", observerClasses);
	} else {
		NSLog(@"DEBUG* failed to enumerate classes");
	}
	[[TweakManager sharedManager] start];
}
