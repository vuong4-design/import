#import "ObserverManager.h"

static NSString *const kObserverClassKey = @"class";
static NSString *const kObserverTimestampKey = @"timestamp";

@interface ObserverManager ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *observers;
@end

@implementation ObserverManager

+ (instancetype)sharedManager {
	static ObserverManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[ObserverManager alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_observers = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)trackObserver:(id)observer {
	if (!observer) {
		return;
	}
	NSString *className = NSStringFromClass([observer class]) ?: @"(unknown)";
	NSDate *timestamp = [NSDate date];
	NSDictionary *entry = @{
		kObserverClassKey: className,
		kObserverTimestampKey: timestamp,
	};
	[self.observers addObject:entry];
	NSLog(@"DEBUG* tracked SKPaymentTransactionObserver %@ at %@", className, timestamp);
}

- (NSArray<NSDictionary *> *)trackedObservers {
	return [self.observers copy];
}

@end
