#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

#import "DynamicObserverHooks.h"

static NSMapTable<Class, NSValue *> *gOriginalImps;
typedef void (*PaymentQueueUpdatedTransactionsIMP)(id, SEL, SKPaymentQueue *, NSArray *);

static void DynamicPaymentQueueUpdatedTransactions(id self, SEL _cmd, SKPaymentQueue *queue, NSArray *transactions) {
	NSValue *impValue = [gOriginalImps objectForKey:[self class]];
	if (impValue) {
		PaymentQueueUpdatedTransactionsIMP originalImp = [impValue pointerValue];
		if (originalImp) {
			originalImp(self, _cmd, queue, transactions);
		}
	}

	NSLog(@"DEBUG* dynamic hook handled %@ updatedTransactions", NSStringFromClass([self class]));
}

static BOOL SwizzleObserverClass(Class cls) {
	SEL updatedSelector = @selector(paymentQueue:updatedTransactions:);
	Method method = class_getInstanceMethod(cls, updatedSelector);
	if (!method) {
		return NO;
	}
	IMP originalImp = method_getImplementation(method);
	if (!originalImp) {
		return NO;
	}
	IMP newImp = (IMP)DynamicPaymentQueueUpdatedTransactions;
	if (originalImp == newImp) {
		return NO;
	}

	[gOriginalImps setObject:[NSValue valueWithPointer:originalImp] forKey:cls];
	method_setImplementation(method, newImp);
	return YES;
}

void InitDynamicObserverHooks(void) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gOriginalImps = [NSMapTable strongToStrongObjectsMapTable];
		unsigned int classCount = 0;
		Class *classes = objc_copyClassList(&classCount);
		if (!classes) {
			NSLog(@"DEBUG* dynamic hook failed to enumerate classes");
			return;
		}

		NSUInteger swizzledCount = 0;
		for (unsigned int i = 0; i < classCount; i++) {
			Class cls = classes[i];
			if (!cls) {
				continue;
			}
			if (!class_conformsToProtocol(cls, @protocol(SKPaymentTransactionObserver))) {
				continue;
			}
			if (SwizzleObserverClass(cls)) {
				swizzledCount++;
			}
		}
		free(classes);

		if (swizzledCount == 0) {
			NSLog(@"DEBUG* dynamic hook found no observer classes; falling back to universal hooks");
		} else {
			NSLog(@"DEBUG* dynamic hook swizzled %lu observer classes", (unsigned long)swizzledCount);
		}
	});
}
