#import <StoreKit/StoreKit.h>

#import "ObserverManager.h"
#import "ExportManager.h"

static NSString *const kObserverClassKey = @"class";
static NSString *const kObserverTimestampKey = @"timestamp";
static NSString *const kObserverPriorityKey = @"priority";

@interface ObserverEntry : NSObject
@property (nonatomic, weak) id observer;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, copy) NSString *className;
- (NSDictionary *)trackingInfo;
@end

@implementation ObserverEntry

- (NSDictionary *)trackingInfo {
	return @{
		kObserverClassKey: self.className ?: @"(unknown)",
		kObserverTimestampKey: self.timestamp ?: [NSDate dateWithTimeIntervalSince1970:0],
		kObserverPriorityKey: @(self.priority),
	};
}

@end

@interface ObserverRoutingObserver : NSObject <SKPaymentTransactionObserver>
@end


@interface ObserverManager ()
@property (nonatomic, strong) NSMutableArray<ObserverEntry *> *observerEntries;
@property (nonatomic, strong) ObserverRoutingObserver *routingObserver;
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
		_observerEntries = [[NSMutableArray alloc] init];
		_routingObserver = [[ObserverRoutingObserver alloc] init];
	}
	return self;
}

- (void)registerObserver:(id)observer priority:(NSInteger)priority {
	if (!observer) {
		return;
	}
	for (ObserverEntry *entry in self.observerEntries) {
		if (entry.observer == observer) {
			return;
		}
	}

	ObserverEntry *entry = [[ObserverEntry alloc] init];
	entry.observer = observer;
	entry.priority = priority;
	entry.timestamp = [NSDate date];
	entry.className = NSStringFromClass([observer class]) ?: @"(unknown)";
	[self.observerEntries addObject:entry];
	NSLog(@"DEBUG* tracked SKPaymentTransactionObserver %@ priority %ld at %@",
		entry.className,
		(long)priority,
		entry.timestamp);
}

- (void)routeUpdatedTransactions:(NSArray *)transactions queue:(id)queue {
	[self purgeReleasedObservers];
	BOOL exportModeEnabled = [ExportManager shared].exportMode;
	NSArray<ObserverEntry *> *entries = [self sortedEntries];
	for (ObserverEntry *entry in entries) {
		id observer = entry.observer;
		if (!observer) {
			continue;
		}
		if (exportModeEnabled && entry.priority != 0) {
			continue;
		}
		if ([observer respondsToSelector:@selector(paymentQueue:updatedTransactions:)]) {
			[observer paymentQueue:queue updatedTransactions:transactions];
		}
	}
}

- (void)purgeReleasedObservers {
	NSIndexSet *indexesToRemove = [self.observerEntries indexesOfObjectsPassingTest:^BOOL(ObserverEntry *entry, NSUInteger idx, BOOL *stop) {
		return entry.observer == nil;
	}];
	if (indexesToRemove.count > 0) {
		[self.observerEntries removeObjectsAtIndexes:indexesToRemove];
		NSLog(@"DEBUG* removed released StoreKit observers");
	}
}

- (NSArray<ObserverEntry *> *)sortedEntries {
	return [self.observerEntries sortedArrayUsingComparator:^NSComparisonResult(ObserverEntry *a, ObserverEntry *b) {
		if (a.priority < b.priority) {
			return NSOrderedAscending;
		}
		if (a.priority > b.priority) {
			return NSOrderedDescending;
		}
		return [a.timestamp compare:b.timestamp];
	}];
}

- (NSArray<NSDictionary *> *)trackedObservers {
	NSMutableArray<NSDictionary *> *results = [[NSMutableArray alloc] init];
	for (ObserverEntry *entry in self.observerEntries) {
		[results addObject:[entry trackingInfo]];
	}
	return [results copy];
}

- (BOOL)isRoutingObserver:(id)observer {
	return observer == self.routingObserver;
}

- (id)routingObserver {
	return _routingObserver;
}

- (void)clearObservers {
	[self.observerEntries removeAllObjects];
	NSLog(@"DEBUG* cleared tracked StoreKit observers");
}

@end

@implementation ObserverRoutingObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	[[ObserverManager sharedManager] routeUpdatedTransactions:transactions queue:queue];
}

@end
